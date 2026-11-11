pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Item {
    id: root

    // =============================================================
    // 1. Primary Battery Device (Laptop / UPS)
    // =============================================================
    readonly property var batteryDevice: {
        var devs = UPower.devices.values;
        if (devs) {
            for (var i = 0; i < devs.length; i++) {
                var d = devs[i];
                if (d && d.isLaptopBattery && d.isPresent) {
                    return d;
                }
            }
            for (var j = 0; j < devs.length; j++) {
                var d2 = devs[j];
                if (d2 && d2.type === UPowerDeviceType.Ups && d2.isPresent) {
                    return d2;
                }
            }
        }
        if (UPower.displayDevice && UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent) {
            return UPower.displayDevice;
        }
        return null;
    }

    // Peripheral devices with batteries reported by UPower (e.g. Logitech HID++ mouse/keyboard)
    readonly property var peripheralDevices: {
        var devs = UPower.devices.values;
        if (!devs) return [];
        var list = [];
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!d || !d.isPresent) continue;
            if (d.isLaptopBattery || d.type === UPowerDeviceType.LinePower || d.type === UPowerDeviceType.Battery) continue;
            list.push(d);
        }
        return list;
    }

    // =============================================================
    // 2. Primary Battery Reactive Properties
    // =============================================================
    readonly property bool hasBattery: batteryDevice !== null
    readonly property bool onBattery: UPower.onBattery
    readonly property int percentage: batteryDevice ? normalizePercentage(batteryDevice.percentage) : 0
    readonly property int state: batteryDevice ? batteryDevice.state : UPowerDeviceState.Unknown

    readonly property bool isCharging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool isFullyCharged: state === UPowerDeviceState.FullyCharged
    readonly property bool isDischarging: state === UPowerDeviceState.Discharging

    readonly property string statusText: {
        if (!hasBattery) return "No battery";
        switch (state) {
            case UPowerDeviceState.Charging:         return "Charging";
            case UPowerDeviceState.Discharging:      return "On battery";
            case UPowerDeviceState.FullyCharged:     return "Fully charged";
            case UPowerDeviceState.PendingCharge:    return "Plugged in (Not charging)";
            case UPowerDeviceState.PendingDischarge: return "Pending discharge";
            case UPowerDeviceState.Empty:            return "Battery empty";
            default:                                 return onBattery ? "On battery" : "AC connected";
        }
    }

    // Power draw or charging rate in Watts (W)
    readonly property double changeRate: batteryDevice ? (batteryDevice.changeRate || 0) : 0
    readonly property string changeRateText: changeRate >= 0.1 ? (changeRate.toFixed(1) + " W") : ""

    // Current energy and full design/last capacity in Wh
    readonly property double energyWh: batteryDevice ? (batteryDevice.energy || 0) : 0
    readonly property double capacityWh: batteryDevice ? (batteryDevice.energyCapacity || 0) : 0
    readonly property string energyText: (capacityWh > 0) ? (energyWh.toFixed(1) + " / " + capacityWh.toFixed(1) + " Wh") : ""

    // Battery health (%)
    readonly property int healthPct: (batteryDevice && batteryDevice.healthSupported)
        ? normalizePercentage(batteryDevice.healthPercentage)
        : -1

    // Estimated time remaining (until empty or until full)
    readonly property string timeRemainingText: {
        if (!batteryDevice) return "";
        if (isCharging && batteryDevice.timeToFull > 60) {
            return formatDuration(batteryDevice.timeToFull) + " until full";
        }
        if (isDischarging && batteryDevice.timeToEmpty > 60) {
            return formatDuration(batteryDevice.timeToEmpty) + " remaining";
        }
        return "";
    }

    // =============================================================
    // 3. Power Profiles (PowerProfiles D-Bus)
    // =============================================================
    readonly property int rawProfile: PowerProfiles.profile
    readonly property bool hasPerformanceProfile: PowerProfiles.hasPerformanceProfile

    readonly property string currentProfileId: {
        switch (rawProfile) {
            case PowerProfile.PowerSaver:  return "power-saver";
            case PowerProfile.Performance: return "performance";
            case PowerProfile.Balanced:
            default:                       return "balanced";
        }
    }

    readonly property string currentProfileName: {
        switch (rawProfile) {
            case PowerProfile.PowerSaver:  return "Power Saver";
            case PowerProfile.Performance: return "Performance";
            case PowerProfile.Balanced:
            default:                       return "Balanced";
        }
    }

    readonly property string currentProfileIcon: {
        switch (rawProfile) {
            case PowerProfile.PowerSaver:  return "󰌪";
            case PowerProfile.Performance: return "󰓅";
            case PowerProfile.Balanced:
            default:                       return "󰗑";
        }
    }

    readonly property string degradationText: {
        switch (PowerProfiles.degradationReason) {
            case PerformanceDegradationReason.HighTemperature: return "Throttled due to high temperature";
            case PerformanceDegradationReason.LapDetected:     return "Throttled due to lap detection";
            default:                                           return "";
        }
    }

    // =============================================================
    // 4. Helper Functions and Actions
    // =============================================================
    function normalizePercentage(val) {
        if (val === undefined || val === null || isNaN(val) || val < 0) return 0;
        var pct = (val > 0 && val <= 1.0) ? (val * 100.0) : val;
        return Math.max(0, Math.min(100, Math.round(pct)));
    }

    function formatDuration(seconds) {
        if (!seconds || isNaN(seconds) || seconds <= 0) return "";
        var totalMin = Math.round(seconds / 60);
        var h = Math.floor(totalMin / 60);
        var m = totalMin % 60;
        if (h > 0) {
            return h + "h " + (m < 10 ? "0" + m : m) + "m";
        }
        return m + " min";
    }

    function peripheralIcon(dev) {
        if (!dev) return "󰁹";
        switch (dev.type) {
            case UPowerDeviceType.Mouse:       return "󰍽";
            case UPowerDeviceType.Keyboard:    return "󰌌";
            case UPowerDeviceType.Headset:     return "󰋎";
            case UPowerDeviceType.Headphones:  return "󰋋";
            case UPowerDeviceType.GamingInput: return "󰊗";
            case UPowerDeviceType.Phone:       return "󰄜";
            case UPowerDeviceType.Touchpad:    return "󰟸";
            case UPowerDeviceType.Pen:         return "󰏬";
            default:                           return "󰁹";
        }
    }

    function setProfile(profileId) {
        if (profileId === "power-saver") {
            PowerProfiles.profile = PowerProfile.PowerSaver;
        } else if (profileId === "performance") {
            PowerProfiles.profile = PowerProfile.Performance;
        } else {
            PowerProfiles.profile = PowerProfile.Balanced;
        }
    }

    function cycleProfile() {
        var nextId = "balanced";
        if (currentProfileId === "power-saver") {
            nextId = "balanced";
        } else if (currentProfileId === "balanced") {
            nextId = hasPerformanceProfile ? "performance" : "power-saver";
        } else {
            nextId = "power-saver";
        }
        setProfile(nextId);
        return nextId;
    }
}
