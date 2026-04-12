import XCTest
@testable import FoodAndFriends

final class UserServiceValidationTests: XCTestCase {

    let service = UserService.shared

    // MARK: - Username Validation

    func testIsValidUsername_validUsername_returnsTrue() {
        XCTAssertTrue(service.isValidUsername("testuser"))
        XCTAssertTrue(service.isValidUsername("user_123"))
        XCTAssertTrue(service.isValidUsername("ABC"))
        XCTAssertTrue(service.isValidUsername("a_b_c_d_e_f_g_h_ij"))
    }

    func testIsValidUsername_tooShort_returnsFalse() {
        XCTAssertFalse(service.isValidUsername("ab"))
        XCTAssertFalse(service.isValidUsername("a"))
        XCTAssertFalse(service.isValidUsername(""))
    }

    func testIsValidUsername_tooLong_returnsFalse() {
        let longName = String(repeating: "a", count: 21)
        XCTAssertFalse(service.isValidUsername(longName))
    }

    func testIsValidUsername_invalidCharacters_returnsFalse() {
        XCTAssertFalse(service.isValidUsername("user name"))
        XCTAssertFalse(service.isValidUsername("user@name"))
        XCTAssertFalse(service.isValidUsername("user.name"))
        XCTAssertFalse(service.isValidUsername("user-name"))
        XCTAssertFalse(service.isValidUsername("user!name"))
    }

    func testIsValidUsername_exactBoundary_valid() {
        let threeChars = "abc"
        let twentyChars = String(repeating: "x", count: 20)
        XCTAssertTrue(service.isValidUsername(threeChars))
        XCTAssertTrue(service.isValidUsername(twentyChars))
    }
}
