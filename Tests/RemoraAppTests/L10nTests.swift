import Foundation
import Testing
@testable import RemoraApp

struct L10nTests {
    @Test
    func languageOverrideReturnsSimplifiedChineseString() {
        let value = L10n.tr("Language", fallback: "Language", modeOverride: .simplifiedChinese)
        #expect(value == "语言")
    }

    @Test
    func languageOverrideReturnsEnglishString() {
        let value = L10n.tr("Language", fallback: "Language", modeOverride: .english)
        #expect(value == "Language")
    }

    @Test
    func permissionsEditorStringsAreLocalizedInSimplifiedChinese() {
        #expect(L10n.tr("Edit Permissions", fallback: "Edit Permissions", modeOverride: .simplifiedChinese) == "编辑权限")
        #expect(L10n.tr("Apply changes recursively", fallback: "Apply changes recursively", modeOverride: .simplifiedChinese) == "同时修改子文件属性")
        #expect(L10n.tr("Owner", fallback: "Owner", modeOverride: .simplifiedChinese) == "所有者")
        #expect(L10n.tr("Public", fallback: "Public", modeOverride: .simplifiedChinese) == "公共")
        #expect(L10n.tr("Read", fallback: "Read", modeOverride: .simplifiedChinese) == "读取")
        #expect(L10n.tr("Write", fallback: "Write", modeOverride: .simplifiedChinese) == "写入")
        #expect(L10n.tr("Execute", fallback: "Execute", modeOverride: .simplifiedChinese) == "可执行")
        #expect(L10n.tr("User", fallback: "User", modeOverride: .simplifiedChinese) == "用户")
        #expect(L10n.tr("Permissions should be a valid octal value, e.g. 0755", fallback: "Permissions should be a valid octal value, e.g. 0755", modeOverride: .simplifiedChinese) == "权限应为有效的八进制值，例如 0755")
    }

    @Test
    func archiveStringsAreLocalizedInSimplifiedChinese() {
        #expect(L10n.tr("Compress", fallback: "Compress", modeOverride: .simplifiedChinese) == "压缩")
        #expect(L10n.tr("Compress Files", fallback: "Compress Files", modeOverride: .simplifiedChinese) == "压缩文件")
        #expect(L10n.tr("Extract To", fallback: "Extract To", modeOverride: .simplifiedChinese) == "解压到")
        #expect(L10n.tr("Extract Archive", fallback: "Extract Archive", modeOverride: .simplifiedChinese) == "解压压缩包")
        #expect(L10n.tr("Archive created.", fallback: "Archive created.", modeOverride: .simplifiedChinese) == "压缩包已创建。")
        #expect(L10n.tr("Archive extracted.", fallback: "Archive extracted.", modeOverride: .simplifiedChinese) == "压缩包已解压。")
        #expect(L10n.tr("Preparing files…", fallback: "Preparing files…", modeOverride: .simplifiedChinese) == "正在准备文件…")
        #expect(L10n.tr("Uploading archive…", fallback: "Uploading archive…", modeOverride: .simplifiedChinese) == "正在上传压缩包…")
        #expect(L10n.tr("Extracting archive…", fallback: "Extracting archive…", modeOverride: .simplifiedChinese) == "正在解压压缩包…")
    }

    @Test
    func terminalActionStringsAreLocalizedInSimplifiedChinese() {
        #expect(L10n.tr("Select All", fallback: "Select All", modeOverride: .simplifiedChinese) == "全选")
        #expect(L10n.tr("Clear Screen", fallback: "Clear Screen", modeOverride: .simplifiedChinese) == "清屏")
        #expect(L10n.tr("Terminal", fallback: "Terminal", modeOverride: .simplifiedChinese) == "终端")
    }
}
