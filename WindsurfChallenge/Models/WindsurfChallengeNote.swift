import Foundation
import CoreData

@objc(WindsurfChallengeNote)
public class WindsurfChallengeNote: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var folder: WindsurfChallengeFolder?
}

extension WindsurfChallengeNote {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WindsurfChallengeNote> {
        return NSFetchRequest<WindsurfChallengeNote>(entityName: "Note")
    }
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        updatedAt = Date()
    }
}

extension WindsurfChallengeNote: Identifiable { }
