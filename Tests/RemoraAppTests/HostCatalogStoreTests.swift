import Testing
@testable import RemoraApp

@MainActor
struct HostCatalogStoreTests {
    @Test
    func quickConnectSupportsExactAndFuzzyMatch() {
        let store = HostCatalogStore()

        let exact = store.quickConnectMatch(input: "prod-api")
        #expect(exact?.name == "prod-api")

        let fuzzy = store.quickConnectMatch(input: "staging")
        #expect(fuzzy?.name == "staging-api")

        let missing = store.quickConnectMatch(input: "unknown-host")
        #expect(missing == nil)
    }

    @Test
    func marksRecentHostsInOrder() {
        let store = HostCatalogStore()
        let first = store.hosts[0]
        let second = store.hosts[1]

        store.markConnected(hostID: first.id)
        store.markConnected(hostID: second.id)
        store.markConnected(hostID: first.id)

        let recents = store.recents(matching: "")
        #expect(recents.first?.id == first.id)
        #expect(recents.dropFirst().first?.id == second.id)
    }

    @Test
    func supportsGroupAndThreadCrud() {
        let store = HostCatalogStore()

        let groupName = store.addGroup(named: "Threads")
        #expect(store.groups.contains(groupName))

        let host = store.addHost(in: groupName)
        #expect(store.host(id: host.id)?.group == groupName)
        #expect(store.groupSections(matching: "").contains(where: { $0.name == groupName && $0.hosts.contains(where: { $0.id == host.id }) }))

        store.deleteHost(id: host.id)
        #expect(store.host(id: host.id) == nil)

        store.deleteGroup(named: groupName)
        #expect(store.groups.contains(groupName) == false)
    }

    @Test
    func supportsRenamePinAndArchiveForHostAndGroup() {
        let store = HostCatalogStore()
        let originalGroup = store.groups.first ?? store.addGroup(named: "Default")
        let host = store.addHost(in: originalGroup)

        let renamedGroup = store.renameGroup(from: originalGroup, to: "Renamed Group")
        #expect(renamedGroup != nil)
        #expect(store.groups.contains("Renamed Group"))
        #expect(store.host(id: host.id)?.group == "Renamed Group")

        let renamedHost = store.renameHost(id: host.id, to: "my-ssh")
        #expect(renamedHost == "my-ssh")
        #expect(store.host(id: host.id)?.name == "my-ssh")

        store.toggleFavorite(hostID: host.id)
        #expect(store.host(id: host.id)?.favorite == true)

        store.archiveHost(id: host.id)
        #expect(store.host(id: host.id)?.group == "Archived")
        #expect(store.groups.contains("Archived"))
    }
}
