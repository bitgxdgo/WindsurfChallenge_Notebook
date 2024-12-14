import Foundation
import CoreData

@objc(WindsurfChallengeFolder)
public class WindsurfChallengeFolder: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var icon: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var notes: Set<WindsurfChallengeNote>?
    @NSManaged public var parentFolder: WindsurfChallengeFolder?
    @NSManaged public var subFolders: Set<WindsurfChallengeFolder>?
}

extension WindsurfChallengeFolder {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WindsurfChallengeFolder> {
        return NSFetchRequest<WindsurfChallengeFolder>(entityName: "Folder")
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
    }
}

// MARK: Generated accessors for notes
extension WindsurfChallengeFolder {
    @objc(addNotesObject:)
    @NSManaged public func addToNotes(_ value: WindsurfChallengeNote)

    @objc(removeNotesObject:)
    @NSManaged public func removeFromNotes(_ value: WindsurfChallengeNote)

    @objc(addNotes:)
    @NSManaged public func addToNotes(_ values: NSSet)

    @objc(removeNotes:)
    @NSManaged public func removeFromNotes(_ values: NSSet)
}

// MARK: Generated accessors for subFolders
extension WindsurfChallengeFolder {
    @objc(addSubFoldersObject:)
    @NSManaged public func addToSubFolders(_ value: WindsurfChallengeFolder)

    @objc(removeSubFoldersObject:)
    @NSManaged public func removeFromSubFolders(_ value: WindsurfChallengeFolder)

    @objc(addSubFolders:)
    @NSManaged public func addToSubFolders(_ values: NSSet)

    @objc(removeSubFolders:)
    @NSManaged public func removeFromSubFolders(_ values: NSSet)
}

extension WindsurfChallengeFolder: Identifiable { }
