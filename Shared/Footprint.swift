import Foundation

/// How much memory the keyboard is actually using, and the high-water mark
/// it has reached.
///
/// A keyboard extension gets roughly 30–80MB before iOS kills it, and being
/// killed does not look like a crash to the person holding the iPad: the
/// keyboard vanishes mid-sentence and the system one takes over. For
/// somebody whose only voice is this board, that is the worst failure the
/// project has.
///
/// The number reported is `phys_footprint`, because that is the one jetsam
/// actually measures — resident size undercounts compressed and IOKit
/// memory and would give a comfortable answer right up until the kill.
///
/// The extension records its own peak into the shared container and the app
/// reads it back, so the ceiling stops being a thing we mean to check one
/// day and becomes a number on a screen.
enum Footprint {
    static let peakKey = "keyboardPeakFootprint"
    static let stampKey = "keyboardPeakFootprintAt"

    /// Bytes, or 0 if the kernel declined to say.
    static var bytes: UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
    }

    static var megabytes: Double { Double(bytes) / 1_048_576 }

    /// Keeps the worst moment, not the last one. The peak is what gets you
    /// killed; the average is what makes you think you are fine.
    static func recordPeak(in store: UserDefaults) {
        let now = megabytes
        guard now > 0 else { return }
        if now > store.double(forKey: peakKey) {
            store.set(now, forKey: peakKey)
            store.set(Date().timeIntervalSince1970, forKey: stampKey)
        }
    }
}
