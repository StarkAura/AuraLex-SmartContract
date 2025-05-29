use auralex_contracts::base::types::{CourseDetails, ResourceType};
use auralex_contracts::interfaces::IAuralex::{IAuralexDispatcher, IAuralexDispatcherTrait};
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const};


fn setup() -> ContractAddress {
    let declare_result = declare("Auralex");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    let deploy_result = contract_class.deploy(@calldata);
    assert(deploy_result.is_ok(), 'Contract deployment failed');

    let (contract_address, _) = deploy_result.unwrap();

    contract_address
}


#[test]
fn test_create_free_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let name: ByteArray = "John";
    let enroll_fee: u256 = 0;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, user, CheatSpan::Indefinite);

    // Call create_course
    let course_id = dispatcher.create_course(name.clone(), user, enroll_fee);

    // Validate that the course ID is correctly incremented
    assert(course_id == 1, 'Course ID should start from 0');

    // Retrieve the course to verify it was stored correctly
    let course = dispatcher.get_course(course_id);

    assert(course.name == name, 'Course title mismatch');
    assert(course.instructor == user, 'instructor description mismatch');
    assert(course.total_enrolled == 0, 'total enrolled mismatch');
    assert(course.enroll_fee == 0, 'enroll fee mismatch');
    assert(course.course_type == ResourceType::Free, 'Course type mismatch');
    assert(course.enroll_fee == enroll_fee, 'enroll_fee mismatch');
}

#[test]
fn test_create_paid_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Test input values
    let user: ContractAddress = contract_address_const::<'user'>();
    let name: ByteArray = "John";

    let enroll_fee: u256 = 100;

    // Ensure the caller is the admin
    cheat_caller_address(contract_address, user, CheatSpan::Indefinite);

    // Call create_course
    let course_id = dispatcher.create_course(name.clone(), user, enroll_fee);

    // Validate that the course ID is correctly incremented
    assert(course_id == 1, 'Course ID should start from 0');

    // Retrieve the course to verify it was stored correctly
    let course = dispatcher.get_course(course_id);

    assert(course.name == name, 'Course title mismatch');
    assert(course.instructor == user, 'instructor description mismatch');
    assert(course.total_enrolled == 0, 'total enrolled mismatch');
    assert(course.enroll_fee == 100, 'enroll fee mismatch');
    assert(course.course_type == ResourceType::Paid, 'Course type mismatch');
    assert(course.enroll_fee == enroll_fee, 'enroll_fee mismatch');
}

#[test]
fn test_enroll_for_free_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Test input values
    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let name: ByteArray = "Free Course";
    let enroll_fee: u256 = 0;

    // Create a free course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Student enrolls for the course with correct fee (0 for free course)
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Verify enrollment by checking updated course details
    let updated_course = dispatcher.get_course(course_id);
    assert(updated_course.total_enrolled == 1, 'Enrollment count should be 1');
    // Verify student is enrolled (if you implement is_enrolled function)
// assert(dispatcher.is_enrolled(course_id, student), 'Student should be enrolled');
}

#[test]
fn test_enroll_for_paid_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Test input values
    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let name: ByteArray = "Paid Course";
    let enroll_fee: u256 = 100;

    // Create a paid course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Student enrolls for the course with correct fee
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 100);

    // Verify enrollment
    let updated_course = dispatcher.get_course(course_id);
    assert(updated_course.total_enrolled == 1, 'Enrollment count should be 1');
}

#[test]
#[should_panic(expected: 'Course does not exist')]
fn test_enroll_nonexistent_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let student: ContractAddress = contract_address_const::<'student'>();

    // Try to enroll in a non-existent course
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(999, 0); // Non-existent course ID
}

#[test]
#[should_panic(expected: 'Already enrolled in course')]
fn test_double_enrollment() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Test input values
    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let name: ByteArray = "Test Course";
    let enroll_fee: u256 = 0;

    // Create a course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Student enrolls for the course
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Try to enroll again (should panic)
    dispatcher.enroll_for_course(course_id, 0);
}

#[test]
fn test_multiple_students_enrollment() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Test input values
    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student1: ContractAddress = contract_address_const::<'student1'>();
    let student2: ContractAddress = contract_address_const::<'student2'>();
    let name: ByteArray = "Popular Course";
    let enroll_fee: u256 = 0;

    // Create a course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // First student enrolls
    cheat_caller_address(contract_address, student1, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Second student enrolls
    cheat_caller_address(contract_address, student2, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Verify both enrollments
    let updated_course = dispatcher.get_course(course_id);
    assert(updated_course.total_enrolled == 2, 'Should have 2 enrolled students');
}

#[test]
#[should_panic(expected: 'Incorrect enrollment fee')]
fn test_enroll_paid_course_wrong_fee() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let name: ByteArray = "Paid Course";
    let enroll_fee: u256 = 100;

    // Create a paid course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Student tries to enroll with wrong fee
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 50); // Wrong fee amount
}

#[test]
#[should_panic(expected: 'Free course requires no fee')]
fn test_enroll_free_course_with_fee() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let name: ByteArray = "Free Course";
    let enroll_fee: u256 = 0;

    // Create a free course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Student tries to enroll with fee for free course
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 10); // Should be 0 for free course
}
