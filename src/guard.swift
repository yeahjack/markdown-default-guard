import Foundation
import AppKit
import CoreServices
import UniformTypeIdentifiers

let unwanted = "com.tencent.workbuddy.mac"
let args = Array(CommandLine.arguments.dropFirst())
var appPath = "/Applications/Visual Studio Code.app"
var index = 0
while index < args.count {
    switch args[index] {
    case "--app":
        guard index + 1 < args.count else { print("--app 后需要应用路径"); exit(2) }
        index += 1
        appPath = args[index]
    case "--check", "--verify-current", "--self-test": break
    default: print("未知参数：\(args[index])"); exit(2)
    }
    index += 1
}
func shouldRestore(_ current: String?) -> Bool {
    current?.lowercased() == unwanted
}
if args.contains("--self-test") {
    let cases: [(String?, Bool)] = [(unwanted, true), (unwanted.uppercased(), true), ("com.microsoft.VSCode", false), ("abnerworks.Typora", false), (nil, false)]
    guard cases.allSatisfy({ shouldRestore($0.0) == $0.1 }) else { exit(1) }
    print("通过：只恢复 WorkBuddy，不干预其他应用或未设置状态")
    exit(0)
}
let appURL = URL(fileURLWithPath: appPath)
guard appPath.hasPrefix("/"), let preferred = Bundle(url: appURL)?.bundleIdentifier,
      preferred.lowercased() != unwanted else {
    print("请选择已安装的 Markdown 阅读器，并提供 .app 的绝对路径")
    exit(2)
}
let inspect = CommandLine.arguments.contains("--check")
let verifySetter = CommandLine.arguments.contains("--verify-current")
let typeIDs = Set(["net.daringfireball.markdown", UTType(filenameExtension: "md")?.identifier].compactMap { $0 }).sorted()
let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/MarkdownDefaultGuard.log")
func log(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    let fm = FileManager.default
    if let attrs = try? fm.attributesOfItem(atPath: logURL.path), let size = attrs[.size] as? NSNumber, size.intValue > 262144 {
        let backup = logURL.appendingPathExtension("1")
        try? fm.removeItem(at: backup)
        try? fm.moveItem(at: logURL, to: backup)
    }
    if !fm.fileExists(atPath: logURL.path) { fm.createFile(atPath: logURL.path, contents: nil) }
    if let file = try? FileHandle(forWritingTo: logURL) {
        defer { try? file.close() }
        _ = try? file.seekToEnd()
        try? file.write(contentsOf: Data(line.utf8))
    }
}
var failed = false
for typeID in typeIDs {
    let current = LSCopyDefaultRoleHandlerForContentType(typeID as CFString, .all)?.takeRetainedValue() as String?
    if inspect { print("\(typeID): \(current ?? "unset")"); continue }
    if verifySetter && current?.lowercased() != preferred.lowercased() {
        print("当前默认应用与目标应用不同，跳过写入验证")
        exit(1)
    }
    guard shouldRestore(current) || verifySetter else { continue }
    guard Bundle(url: appURL)?.bundleIdentifier == preferred else {
        log("ERROR: target application missing or bundle identifier mismatch")
        failed = true
        continue
    }
    guard let contentType = UTType(typeID) else { log("ERROR: unknown content type \(typeID)"); failed = true; continue }
    var completed = false
    var writeError: Error?
    NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: contentType) { error in
        writeError = error
        completed = true
    }
    let deadline = Date().addingTimeInterval(15)
    while !completed && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    let after = LSCopyDefaultRoleHandlerForContentType(typeID as CFString, .all)?.takeRetainedValue() as String?
    if completed && writeError == nil && after?.lowercased() == preferred.lowercased() {
        if verifySetter { print("PASS: native setter completed; \(typeID) remains \(preferred)") }
        else { log("Restored \(typeID) from \(unwanted) to \(preferred)") }
    } else {
        let message = "ERROR: restore \(typeID), completed=\(completed), error=\(String(describing: writeError)), observed=\(after ?? "unset")"
        log(message)
        if verifySetter { print(message) }
        failed = true
    }
}
exit(failed ? 1 : 0)
