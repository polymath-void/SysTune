use libc::{bind, poll, pollfd, sockaddr_nl, socket, AF_NETLINK, NETLINK_KOBJECT_UEVENT, POLLIN, SOCK_RAW};
use std::collections::HashMap;
use std::fs;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

const SYS_DIR: &str = "/data/adb/modules/SysTune";

struct AppState {
    last_zone: String,
    last_scr: String,
    last_chg: String,
    therm_throttled: bool,
    last_pause_ts: u64,
    last_thermal_action_ts: u64,
}

struct Config {
    saver_threshold: u32,
    balanced_threshold: u32,
    max_daily_soc: u32,
    therm_hi: u32,
    therm_lo: u32,
    neural_therm_threshold: i32,
    neural_renice_val: i32,
    neural_mem_thresh: u64,
}

fn create_singleton_lock() {
    let pid_file = format!("{}/state/service.pid", SYS_DIR);
    let _ = fs::create_dir_all(format!("{}/state", SYS_DIR));
    let _ = fs::write(pid_file, std::process::id().to_string());
}

fn set_oom_adj() {
    let _ = fs::write("/proc/self/oom_score_adj", "-1000");
}

fn sys_read(path: &str) -> Option<String> {
    fs::read_to_string(path).ok().map(|s| s.trim().to_string())
}

fn sys_write(path: &str, val: &str) {
    let _ = fs::write(path, val);
}

fn get_battery_level() -> Option<u32> {
    sys_read("/sys/class/power_supply/battery/capacity").and_then(|s| s.parse().ok())
}

fn get_battery_status() -> Option<String> {
    sys_read("/sys/class/power_supply/battery/status")
}

fn get_battery_temp() -> Option<u32> {
    sys_read("/sys/class/power_supply/battery/temp").and_then(|s| s.parse().ok())
}

fn get_screen_state() -> &'static str {
    if let Some(val) = sys_read("/sys/class/backlight/panel0-backlight/brightness") {
        if val == "0" { return "ScreenOff"; } else { return "ScreenOn"; }
    }
    if let Some(val) = sys_read("/sys/class/leds/lcd-backlight/brightness") {
        if val == "0" { return "ScreenOff"; } else { return "ScreenOn"; }
    }
    "ScreenOn"
}

fn check_thermal_anomaly(state: &mut AppState, cfg: &Config) {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
    if now - state.last_thermal_action_ts < 30 { return; } // 30s cooldown

    if let Ok(temp_str) = fs::read_to_string("/sys/class/thermal/thermal_zone0/temp") {
        if let Ok(temp) = temp_str.trim().parse::<i32>() {
            if temp > cfg.neural_therm_threshold {
                if let Ok(output) = Command::new("top").args(["-n", "1", "-m", "5"]).output() {
                    let top_out = String::from_utf8_lossy(&output.stdout);
                    for line in top_out.lines() {
                        if line.contains(" 9") && line.contains(".") || line.contains("100.") {
                            if let Some(pid_str) = line.split_whitespace().next() {
                                let _ = Command::new("renice").args(["-n", &cfg.neural_renice_val.to_string(), "-p", pid_str]).spawn();
                                state.last_thermal_action_ts = now;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
}

fn check_memory_pressure(cfg: &Config) {
    if let Ok(meminfo) = fs::read_to_string("/proc/meminfo") {
        let mut total = 0;
        let mut avail = 0;
        for line in meminfo.lines() {
            if line.starts_with("MemTotal:") {
                total = line.split_whitespace().nth(1).unwrap_or("0").parse::<u64>().unwrap_or(0);
            } else if line.starts_with("MemAvailable:") {
                avail = line.split_whitespace().nth(1).unwrap_or("0").parse::<u64>().unwrap_or(0);
                break;
            }
        }
        if total > 0 && avail > 0 && avail < (total * cfg.neural_mem_thresh / 100) {
            sys_write("/proc/sys/vm/drop_caches", "3");
        }
    }
}

fn load_global_config() -> Config {
    let mut cfg = Config { 
        saver_threshold: 30, balanced_threshold: 80, max_daily_soc: 85, 
        therm_hi: 380, therm_lo: 340, 
        neural_therm_threshold: 45000, neural_renice_val: 10, neural_mem_thresh: 15 
    };
    let paths = vec![
        format!("{}/config/global.conf", SYS_DIR),
        format!("{}/config/orchestrator.conf", SYS_DIR),
        format!("{}/config/neural.conf", SYS_DIR),
    ];
    for p in paths {
        if let Ok(content) = fs::read_to_string(&p) {
            for line in content.lines() {
                let parts: Vec<&str> = line.splitn(2, '=').collect();
                if parts.len() == 2 {
                    let key = parts[0].trim();
                    let val = parts[1].trim().trim_matches('"').parse::<i32>().unwrap_or(0);
                    match key {
                        "BATTERY_SAVER" => cfg.saver_threshold = val as u32,
                        "BALANCED" => cfg.balanced_threshold = val as u32,
                        "MAX_DAILY_SOC" => cfg.max_daily_soc = val as u32,
                        "THERM_HI" => cfg.therm_hi = val as u32,
                        "THERM_LO" => cfg.therm_lo = val as u32,
                        "NEURAL_THERM_THRESHOLD" => cfg.neural_therm_threshold = val,
                        "NEURAL_RENICE_VAL" => cfg.neural_renice_val = val,
                        "NEURAL_MEM_THRESH" => cfg.neural_mem_thresh = val as u64,
                        _ => {}
                    }
                }
            }
        }
    }
    cfg
}

fn parse_conf(path: &str) -> HashMap<String, String> {
    let mut map = HashMap::new();
    if let Ok(content) = fs::read_to_string(path) {
        for line in content.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') { continue; }
            let parts: Vec<&str> = line.splitn(2, '=').collect();
            if parts.len() == 2 {
                let key = parts[0].trim().to_string();
                let val = parts[1].trim().trim_matches('"').to_string();
                map.insert(key, val);
            }
        }
    }
    map
}

fn log_msg(msg: &str) {
    if std::path::Path::new(&format!("{}/state/logging_enabled", SYS_DIR)).exists() {
        use std::io::Write;
        if let Ok(mut file) = fs::OpenOptions::new().create(true).append(true).open(format!("{}/logs/service.log", SYS_DIR)) {
            let _ = writeln!(file, "{}", msg);
        }
    }
}

// ==============================================
// 1. AUTO PROFILE LOGIC
// ==============================================
fn apply_profile_natively(zone: &str, level: u32) {
    let conf_path = format!("{}/config/profiles/{}.conf", SYS_DIR, zone);
    let map = parse_conf(&conf_path);

    let _ = fs::write(format!("{}/state/auto_profile.status", SYS_DIR), format!("Profile: {}\nBattery: {}\n", zone, level));
    let _ = fs::write(format!("{}/state/last_profile", SYS_DIR), zone);

    let sys_w = |p: &str, k: &str| { if let Some(v) = map.get(k) { sys_write(p, v); } };

    // CPU Policies
    sys_w("/sys/devices/system/cpu/cpufreq/policy0/scaling_governor", "CPU_LITTLE_GOV");
    sys_w("/sys/devices/system/cpu/cpufreq/policy0/scaling_min_freq", "CPU_LITTLE_MIN");
    sys_w("/sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq", "CPU_LITTLE_MAX");
    sys_w("/sys/devices/system/cpu/cpufreq/policy6/scaling_governor", "CPU_BIG_GOV");
    sys_w("/sys/devices/system/cpu/cpufreq/policy6/scaling_min_freq", "CPU_BIG_MIN");
    sys_w("/sys/devices/system/cpu/cpufreq/policy6/scaling_max_freq", "CPU_BIG_MAX");

    // GPU & Touch
    sys_w("/sys/class/devfreq/13000000.mali/governor", "GPU_GOV");
    sys_w("/sys/class/devfreq/13000000.mali/max_freq", "GPU_MAX");
    sys_w("/sys/module/msm_input/parameters/touch_boost", "TOUCH_BOOST");

    // UClamp
    let uclamp_fg = map.get("UCLAMP_FG_MIN").cloned().unwrap_or_default();
    let uclamp_bg = map.get("UCLAMP_BG_MAX").cloned().unwrap_or_default();
    if std::path::Path::new("/dev/cpuctl/top-app").exists() {
        sys_write("/dev/cpuctl/top-app/cpu.uclamp.min", &uclamp_fg);
        sys_write("/dev/cpuctl/background/cpu.uclamp.max", &uclamp_bg);
    } else {
        sys_write("/sys/fs/cgroup/cpu/top-app/cpu.uclamp.min", &uclamp_fg);
        sys_write("/sys/fs/cgroup/cpu/background/cpu.uclamp.max", &uclamp_bg);
    }

    tune_rate_limits(&map);
    tune_runtime(&map);
}

fn tune_rate_limits(map: &HashMap<String, String>) {
    let up = map.get("RATE_UP_US").cloned().unwrap_or_default();
    let down = map.get("RATE_DOWN_US").cloned().unwrap_or_default();
    if up.is_empty() { return; }

    if let Ok(entries) = fs::read_dir("/sys/devices/system/cpu/cpufreq/") {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.file_name().unwrap_or_default().to_string_lossy().starts_with("policy") {
                if let Some(gov) = sys_read(&format!("{}/scaling_governor", path.display())) {
                    if gov == "schedutil" || gov == "sugov_ext" {
                        sys_write(&format!("{}/{}/up_rate_limit_us", path.display(), gov), &up);
                        sys_write(&format!("{}/{}/down_rate_limit_us", path.display(), gov), &down);
                        sys_write(&format!("{}/{}/rate_limit_us", path.display(), gov), &up);
                    }
                }
            }
        }
    }
}

fn tune_runtime(map: &HashMap<String, String>) {
    let queues = vec!["/sys/block/sda/queue", "/sys/block/mmcblk0/queue"];
    for q in queues {
        sys_write(&format!("{}/scheduler", q), "mq-deadline");
        sys_write(&format!("{}/add_random", q), "0");
        sys_write(&format!("{}/iostats", q), "0");
    }

    if map.get("FBT_ENABLE").map(|v| v == "1").unwrap_or(false) {
        let p = "/sys/kernel/fpsgo";
        let sys_w = |k: &str, n: &str| { if let Some(v) = map.get(k) { sys_write(&format!("{}/{}", p, n), v); } };
        sys_w("FBT_BOOST_TA", "fbt/boost_ta");
        sys_w("FBT_RESCUE_PERCENT", "fbt/rescue_percent");
        sys_w("FBT_ULTRA_RESCUE", "fbt/ultra_rescue");
        sys_w("FBT_FLOOR_BOUND", "fbt/floor_bound");
        sys_w("FBT_CAM_BOOST", "fbt_cam/fbt_cam_uclamp_boost_enable");
    }

    if let Some(lmk) = map.get("LMK_MINFREE") {
        sys_write("/sys/module/lowmemorykiller/parameters/minfree", lmk);
    }

    if let Some(slack) = map.get("TIMER_SLACK") {
        if let Ok(entries) = fs::read_dir("/proc/") {
            for entry in entries.flatten() {
                let name = entry.file_name();
                let name_str = name.to_string_lossy();
                if name_str.chars().all(char::is_numeric) {
                    if let Ok(status) = fs::read_to_string(format!("/proc/{}/status", name_str)) {
                        for line in status.lines() {
                            if line.starts_with("Uid:") {
                                let parts: Vec<&str> = line.split_whitespace().collect();
                                if parts.len() >= 2 {
                                    if let Ok(uid) = parts[1].parse::<u32>() {
                                        if uid >= 10000 {
                                            if let Ok(cmdline) = fs::read_to_string(format!("/proc/{}/cmdline", name_str)) {
                                                if cmdline.contains('.') {
                                                    sys_write(&format!("/proc/{}/timerslack_ns", name_str), slack);
                                                }
                                            }
                                        }
                                    }
                                }
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    if let Some(apps) = map.get("BLOAT_APPS") {
        if let Some(mode) = map.get("APP_RESTRICTION") {
            for app in apps.split_whitespace() {
                let _ = Command::new("cmd").args(["appops", "set", app, "RUN_IN_BACKGROUND", mode]).spawn();
            }
        }
    }
}


// ==============================================
// 2. WIFI WORKER
// ==============================================
fn manage_wifi_worker(zone: &str, scr: &str) {
    let conf_path = format!("{}/config/profiles/{}.conf", SYS_DIR, zone);
    let map = parse_conf(&conf_path);

    if let Some(cong) = map.get("TCP_CONG") { sys_write("/proc/sys/net/ipv4/tcp_congestion_control", cong); }
    if let Some(ret) = map.get("TCP_SYN_RETRIES") { sys_write("/proc/sys/net/ipv4/tcp_syn_retries", ret); }
    if let Some(start) = map.get("TCP_SLOW_START") { sys_write("/proc/sys/net/ipv4/tcp_slow_start_after_idle", start); }

    if scr == "ScreenOn" {
        if let Some(boost) = map.get("FBT_BOOST_TA") {
            if let Some(fg) = sys_read("/dev/cpuset/foreground/tasks") {
                if let Some(pid) = fg.split_whitespace().last() {
                    if pid.parse::<u32>().unwrap_or(0) > 2000 {
                        sys_write("/sys/kernel/fpsgo/composer/fpsgo_control_pid", pid);
                        sys_write("/sys/kernel/fpsgo/fbt/fbt_attr_by_pid", &format!("{} {}", pid, boost));
                    }
                }
            }
        }
    }
}

// ==============================================
// 3. BATTERY SAFE
// ==============================================
fn manage_battery_safe(level: u32, stat: &str, cfg: &Config, state: &mut AppState) {
    let base = "/sys/class/power_supply/mtk-master-charger";
    let temp = get_battery_temp().unwrap_or(0);

    if stat != "Charging" || level < 80 {
        state.last_pause_ts = 0;
        if stat != "Charging" { return; }
    }

    let mut tag = "";
    
    if temp >= cfg.therm_hi || state.therm_throttled {
        if temp <= cfg.therm_lo {
            state.therm_throttled = false;
        } else {
            state.therm_throttled = true;
            sys_write(&format!("{}/input_current_limit", base), "500000");
            tag = "THERMAL_THROTTLE";
        }
    }

    if tag.is_empty() && level >= cfg.max_daily_soc {
        sys_write(&format!("{}/input_current_limit", base), "0");
        sys_write(&format!("{}/constant_charge_current_max", base), "0");
        tag = "LONGEVITY_CAP_HALT";
    }

    if tag.is_empty() {
        let now = SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs();
        let elapsed = now - state.last_pause_ts;

        let mut current = 3200000;
        if level < 50 {
            tag = "PHASE_1_FAST";
        } else if level < 80 {
            current = 2000000;
            tag = "PHASE_2_SCALED";
        } else {
            if state.last_pause_ts == 0 {
                state.last_pause_ts = now;
                current = 500000;
                tag = "PHASE_3_PULSE_START";
            } else if elapsed < 300 {
                current = 500000;
                tag = "PHASE_3_PULSE_WAIT";
            } else {
                current = 1000000;
                tag = "PHASE_3_RESUME";
            }
        }

        sys_write(&format!("{}/input_current_limit", base), &current.to_string());
        sys_write(&format!("{}/constant_charge_current_max", base), &current.to_string());
    }

    log_msg(&format!("[BatterySafe] {} @ {}% ({}C)", tag, level, temp/10));
}

// ==============================================
// 4. MAIN LOOP
// ==============================================
fn check_and_apply(state: &mut AppState, cfg: &Config) -> i32 {
    let level = match get_battery_level() {
        Some(l) => l,
        None => return 5000,
    };
    let stat = get_battery_status().unwrap_or_else(|| "Unknown".to_string());
    let scr = get_screen_state().to_string();
    
    // If we are below the threshold AND not charging, go into battery_saver.
    // Otherwise (charging, or above threshold), use balanced.
    let zone = if level <= cfg.saver_threshold && stat != "Charging" { 
        "battery_saver" 
    } else { 
        "balanced" 
    }.to_string();
    
    let mut zone_changed = false;
    let mut scr_changed = false;
    
    if zone != state.last_zone { zone_changed = true; state.last_zone = zone.clone(); }
    if scr != state.last_scr { scr_changed = true; state.last_scr = scr.clone(); }
    
    if zone_changed || scr_changed {
        apply_profile_natively(&zone, level);
        manage_wifi_worker(&zone, &scr);
    }
    
    if stat == "Charging" || stat != state.last_chg {
        manage_battery_safe(level, &stat, cfg, state);
        state.last_chg = stat.clone();
    }
    
    check_thermal_anomaly(state, cfg);
    check_memory_pressure(cfg);
    
    if scr == "ScreenOn" { 10000 } else { 60000 }
}

fn fallback_loop(mut state: AppState, cfg: Config) {
    loop {
        let timeout = check_and_apply(&mut state, &cfg);
        std::thread::sleep(std::time::Duration::from_millis(timeout as u64));
    }
}

fn listen_loop(mut state: AppState, cfg: Config) {
    unsafe {
        let fd = socket(AF_NETLINK, SOCK_RAW | libc::SOCK_CLOEXEC, NETLINK_KOBJECT_UEVENT);
        if fd < 0 { fallback_loop(state, cfg); return; }

        let mut addr: sockaddr_nl = std::mem::zeroed();
        addr.nl_family = AF_NETLINK as u16;
        addr.nl_groups = 1;
        addr.nl_pid = std::process::id();

        if bind(fd, &addr as *const _ as *const _, std::mem::size_of::<sockaddr_nl>() as u32) < 0 {
            libc::close(fd);
            fallback_loop(state, cfg);
            return;
        }

        let mut pfd = pollfd { fd, events: POLLIN, revents: 0 };
        let mut buf = [0u8; 4096];
        let mut timeout = 60000;
        
        loop {
            let res = poll(&mut pfd, 1, timeout);
            if res > 0 && (pfd.revents & POLLIN) != 0 {
                libc::recv(fd, buf.as_mut_ptr() as *mut libc::c_void, buf.len(), libc::MSG_DONTWAIT);
            }
            timeout = check_and_apply(&mut state, &cfg);
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() == 3 && args[1] == "--apply" {
        let zone = &args[2];
        let level = get_battery_level().unwrap_or(50);
        let stat = get_battery_status().unwrap_or_else(|| "Unknown".to_string());
        let scr = get_screen_state().to_string();
        
        apply_profile_natively(zone, level);
        manage_wifi_worker(zone, &scr);
        
        let cfg = load_global_config();
        let mut state = AppState {
            last_zone: String::new(), last_scr: String::new(), last_chg: String::new(),
            therm_throttled: false, last_pause_ts: 0, last_thermal_action_ts: 0,
        };
        manage_battery_safe(level, &stat, &cfg, &mut state);
        return;
    }

    set_oom_adj();
    create_singleton_lock();
    let cfg = load_global_config();
    let state = AppState {
        last_zone: String::new(), last_scr: String::new(), last_chg: String::new(),
        therm_throttled: false, last_pause_ts: 0, last_thermal_action_ts: 0,
    };
    listen_loop(state, cfg);
}
