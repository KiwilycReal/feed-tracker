#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

public final class FeedTrackerExclusiveFileLock {
    private var descriptor: Int32?

    public init(fileURL: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        let descriptor = open(fileURL.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw CocoaError(.fileReadUnknown)
        }

        guard flock(descriptor, LOCK_EX) == 0 else {
            close(descriptor)
            throw CocoaError(.fileReadUnknown)
        }

        self.descriptor = descriptor
    }

    deinit {
        unlock()
    }

    public func unlock() {
        guard let descriptor else {
            return
        }

        flock(descriptor, LOCK_UN)
        close(descriptor)
        self.descriptor = nil
    }
}
