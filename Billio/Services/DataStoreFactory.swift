import Foundation
import SwiftData

enum DataStoreFactory {
    static let cloudContainerIdentifier = "iCloud.JIANGJINGZHE.Billio"

    struct Result {
        let container: ModelContainer
        let usesCloudKit: Bool
    }

    static func makeContainer() -> Result {
        let schema = Schema([
            Bill.self,
            PaymentRecord.self,
            PaymentMethod.self
        ])

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return makeLocalContainer(schema: schema)
        }

        let cloudConfiguration = ModelConfiguration(
            "Billio",
            schema: schema,
            cloudKitDatabase: .private(cloudContainerIdentifier)
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [cloudConfiguration]
            )
            return Result(container: container, usesCloudKit: true)
        } catch {
            return makeLocalContainer(schema: schema)
        }
    }

    private static func makeLocalContainer(schema: Schema) -> Result {
        let localConfiguration = ModelConfiguration(
            "Billio",
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [localConfiguration]
            )
            return Result(
                container: container,
                usesCloudKit: false
            )
        } catch {
            fatalError("Unable to initialize Billio's data store: \(error)")
        }
    }
}
