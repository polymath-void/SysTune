use libc::{bind, poll, pollfd, sockaddr_nl, socket, AF_NETLINK, NETLINK_KOBJECT_UEVENT, POLLIN, SOCK_RAW};
use std::fs;
use std::process::Command;
use std::time::Duration;

const SYS_DIR: &str = "/data/adb/modules/SysTune";

fn create_singleton_lock() {
    let pid_file = format!("{}/state/service.pid", SYS_DIR);
    let _ = fs::create_dir_all(format!("{}/state", SYS_DIR));
    let _ = fs::write(pid_file, std::process::id().to_string());
}

fn set_oom_adj() {
    let _ = fs::write("/proc/self/oom_score_adj", "-1000");
}

fn read_sys_node(path: &str) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

fn get_battery_level() -> Option<u32> {
    read_sys_node("/sys/class/power_supply/battery/capacity")
        .and_then(|s| s.parse().ok())
}

fn get_battery_status() -> Option<String> {
    read_sys_node("/sys/class/power_supply/battery/status")
}

fn get_screen_state() -> &'static str {
    if let Some(val) = read_sys_node("/sys/class/backlight/panel0-backlight/brightness") {
        if val == "0" { return "ScreenOff"; } else { return "ScreenOn"; }
    }
    if let Some(val) = read_sys_node("/sys/class/leds/lcd-backlight/brightness") {
        if val == "0" { return "ScreenOff"; } else { return "ScreenOn"; }
    }
    "ScreenOn" // fallback
}

struct Config {
    saver_threshold: u32,
    balanced_threshold: u32,
}

impl Config {
    fn load() -> Self {
        let mut cfg = Config { saver_threshold: 30, balanced_threshold: 80 };
        let path = format!("{}/config/orchestrator.conf", SYS_DIR);
        if let Ok(content) = fs::read_to_string(path) {
            for line in content.lines() {
                let parts: Vec<&str> = line.split('=').collect();
                if parts.len() == 2 {
                    let key = parts[0].trim();
                    let val = parts[1].trim().parse::<u32>().unwrap_or(0);
                    match key {
                        "BATTERY_SAVER" => cfg.saver_threshold = val,
                        "BALANCED_SMOOTH" => cfg.balanced_threshold = val,
                        _ => {}
                    }
                }
            }
        }
        cfg
    }
}

fn determine_zone(level: u32, cfg: &Config) -> &'static str {
    if level <= cfg.saver_threshold {
        "battery_saver"
    } else if level <= cfg.balanced_threshold {
        "balanced"
    } else {
        "balanced_smooth"
    }
}

fn run_worker(zone: &str, level: u32, stat: &str, script: &str) {
    let script_path = format!("{}/{}", SYS_DIR, script);
    if std::path::Path::new(&script_path).exists() {
        let _ = Command::new("sh")
            .arg(&script_path)
            .env("NEW_PROFILE", zone)
            .env("CUR_BAT", level.to_string())
            .env("CUR_STAT", stat)
            .spawn();
    }
}

fn check_and_apply(last_zone: &mut String, last_scr: &mut String, last_chg: &mut String) -> i32 {
    let cfg = Config::load();
    
    let level = match get_battery_level() {
        Some(l) => l,
        None => return 5000, // retry if sys node not ready
    };
    let stat = get_battery_status().unwrap_or_else(|| "Unknown".to_string());
    let scr = get_screen_state().to_string();
    let zone = determine_zone(level, &cfg).to_string();
    
    let mut zone_changed = false;
    let mut scr_changed = false;
    
    if zone != *last_zone { zone_changed = true; *last_zone = zone.clone(); }
    if scr != *last_scr { scr_changed = true; *last_scr = scr.clone(); }
    
    if zone_changed || scr_changed {
        run_worker(&zone, level, &stat, "auto_profile.sh");
        run_worker(&zone, level, &stat, "wifi_worker.sh");
    }
    
    if stat == "Charging" || stat != *last_chg {
        run_worker(&zone, level, &stat, "battery_safe.sh");
        *last_chg = stat.clone();
    }
    
    if scr == "ScreenOn" {
        run_worker(&zone, level, &stat, "wifi_worker.sh");
        10000 // 10s timeout
    } else {
        60000 // 60s timeout
    }
}

fn fallback_loop() {
    let mut last_zone = String::new();
    let mut last_scr = String::new();
    let mut last_chg = String::new();
    loop {
        let timeout = check_and_apply(&mut last_zone, &mut last_scr, &mut last_chg);
        std::thread::sleep(Duration::from_millis(timeout as u64));
    }
}

fn listen_loop() {
    unsafe {
        let fd = socket(AF_NETLINK, SOCK_RAW | libc::SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
        if fd < 0 {
            fallback_loop();
            return;
        }

        let mut addr: sockaddr_nl = std::mem::zeroed();
        addr.nl_family = AF_NETLINK as u16;
        addr.nl_groups = 1;
        addr.nl_pid = std::process::id();

        if bind(fd, &addr as *const _ as *const _, std::mem::size_of::<sockaddr_nl>() as u32) < 0 {
            libc::close(fd);
            fallback_loop();
            return;
        }

        let mut pfd = pollfd {
            fd,
            events: POLLIN,
            revents: 0,
        };

        let mut buf = [0u8; 4096];
        let mut last_zone = String::new();
        let mut last_scr = String::new();
        let mut last_chg = String::new();
        let mut timeout = 60000;
        
        loop {
            let res = poll(&mut pfd, 1, timeout);
            
            if res > 0 && (pfd.revents & POLLIN) != 0 {
                libc::recv(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len(), libc::MSG_DONTWAIT);
            }
            
            timeout = check_and_apply(&mut last_zone, &mut last_scr, &mut last_chg);
        }
    }
}

fn main() {
    set_oom_adj();
    create_singleton_lock();
    listen_loop();
}
