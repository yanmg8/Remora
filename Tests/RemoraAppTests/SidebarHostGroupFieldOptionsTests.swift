import Testing
@testable import RemoraApp

struct SidebarHostGroupFieldOptionsTests {
    @Test
    func mergesExistingAndStagedGroupsWithoutEmptyValues() {
        let options = SidebarHostGroupFieldOptions.merged(
            existing: ["Production", "", "Staging"],
            staged: ["Staging", "Sandbox", " "]
        )

        #expect(options == ["Production", "Staging", "Sandbox"])
    }

    @Test
    func stagingAddsTrimmedCustomGroupOnce() {
        let staged = SidebarHostGroupFieldOptions.staged(
            existing: ["Production"],
            currentText: "  Sandbox  ",
            staged: []
        )

        #expect(staged == ["Sandbox"])
    }

    @Test
    func stagingSkipsExistingOrEmptyGroups() {
        let existingMatch = SidebarHostGroupFieldOptions.staged(
            existing: ["Production"],
            currentText: "Production",
            staged: []
        )
        let emptyValue = SidebarHostGroupFieldOptions.staged(
            existing: ["Production"],
            currentText: "   ",
            staged: ["Sandbox"]
        )

        #expect(existingMatch.isEmpty)
        #expect(emptyValue == ["Sandbox"])
    }
}
