use std::fs::{self, OpenOptions};
use std::os::fd::AsRawFd;
use std::path::PathBuf;

slint::include_modules!();

const EC_SET_PROFILE: libc::c_ulong = 0x4422;
const EC_GET_PROFILE: libc::c_ulong = 0x4423;
const EC_GET_FAN_SPEED: libc::c_ulong = 0x4424;

fn find_cpu_thermal_zone() -> Option<PathBuf> {
    let zones_dir = "/sys/class/thermal/";

    if let Ok(entries) = fs::read_dir(zones_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            let type_path = path.join("type");

            if let Ok(zone_type) = fs::read_to_string(&type_path) {
                let name = zone_type.trim().to_lowercase();

                if name.contains("x86_pkg_temp")
                    || name.contains("coretemp")
                    || name.contains("k10temp")
                {
                    println!("Found CPU thermal zone: {} ({})", path.display(), name);
                    return Some(path.join("temp"));
                }
            }
        }
    }
    eprintln!("Warning: Could not auto-detect CPU thermal zone.");
    None
}

fn get_cpu_temp(sensor_path: &PathBuf) -> Option<i32> {
    if let Ok(temp_str) = fs::read_to_string(sensor_path) && let Ok(millidegrees) = temp_str.trim().parse::<i32>() {
        return Some(millidegrees / 1000);
    }
    None
}

fn get_current_profile() -> Option<i32> {
    match OpenOptions::new().read(true).open("/dev/hp_ec_thermal") {
        Ok(file) => unsafe {
            let result = libc::ioctl(file.as_raw_fd(), EC_GET_PROFILE, 0);
            if (0..=4).contains(&result) {
                Some(result as i32)
            } else {
                None
            }
        },
        Err(_) => None,
    }
}

fn get_fan_speed_raw() -> Option<i32> {
    match OpenOptions::new().read(true).open("/dev/hp_ec_thermal") {
        Ok(file) => unsafe {
            let result = libc::ioctl(file.as_raw_fd(), EC_GET_FAN_SPEED, 0);
            if result >= 0 {
                Some(result as i32)
            } else {
                None
            }
        },
        Err(_) => None,
    }
}

fn apply_thermal_profile(profile_code: usize) {
    if let Ok(file) = OpenOptions::new().write(true).open("/dev/hp_ec_thermal") {
        unsafe {
            libc::ioctl(
                file.as_raw_fd(),
                EC_SET_PROFILE,
                profile_code as libc::c_ulong,
            );
        }
    }
}

fn main() -> Result<(), slint::PlatformError> {
    let ui = AppWindow::new()?;

    slint::set_xdg_app_id("hp_ec_gui").ok();

    if let Some(actual_profile) = get_current_profile() {
        ui.set_active_profile(actual_profile);
    }

    ui.on_set_profile(move |profile_code| {
        apply_thermal_profile(profile_code as usize);
    });

    let thermal_path = find_cpu_thermal_zone();
    let ui_handle = ui.as_weak();
    let timer = slint::Timer::default();
    let mut tick_counter = 0;

    timer.start(
        slint::TimerMode::Repeated,
        std::time::Duration::from_millis(1000),
        move || {
            if let Some(ui) = ui_handle.upgrade() {
                if let Some(raw_val) = get_fan_speed_raw() {
                    let rpm = raw_val * 100;
                    let percent = ((raw_val as f32 / 54.0) * 100.0).round() as i32;
                    ui.set_fan_rpm(rpm);
                    ui.set_fan_percent(percent);
                }

                if let Some(ref path) = thermal_path && let Some(temp_celsius) = get_cpu_temp(path) {
                    ui.set_cpu_temp(temp_celsius);
                }

                tick_counter += 1;
                if tick_counter >= 60 {
                    tick_counter = 0;

                    if let Some(actual_profile) = get_current_profile() {
                        ui.set_active_profile(actual_profile);
                    }
                }
            }
        },
    );

    ui.run()
}
