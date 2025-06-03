use auralex_contracts::base::types::{Certificate, CourseDetails, ResourceType};
use auralex_contracts::interfaces::IAuralex::{IAuralexDispatcher, IAuralexDispatcherTrait};
use snforge_std::{CheatSpan, ContractClassTrait, DeclareResultTrait, cheat_caller_address, declare};
use starknet::{ContractAddress, contract_address_const};


fn setup() -> ContractAddress {
    let declare_result = declare("Auralex");
    assert(declare_result.is_ok(), 'Contract declaration failed');

    let contract_class = declare_result.unwrap().contract_class();
    let mut calldata = array![];

    // Use a dummy token address - we'll only test free courses
    let dummy_token_address: ContractAddress = contract_address_const::<'dummy_token'>();
    calldata.append(dummy_token_address.into());

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

    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student: ContractAddress = contract_address_const::<'student'>();
    let name: ByteArray = "Free Course";
    let enroll_fee: u256 = 0;

    // Create a free course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Student enrolls for the course
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Verify enrollment
    let updated_course = dispatcher.get_course(course_id);
    assert(updated_course.total_enrolled == 1, 'Enrollment count should be 1');

    // Verify student is enrolled
    assert(dispatcher.is_enrolled(course_id, student), 'Student should be enrolled');
}

#[test]
fn test_multiple_students_free_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let instructor: ContractAddress = contract_address_const::<'instructor'>();
    let student1: ContractAddress = contract_address_const::<'student1'>();
    let student2: ContractAddress = contract_address_const::<'student2'>();
    let student3: ContractAddress = contract_address_const::<'student3'>();
    let name: ByteArray = "Popular Free Course";
    let enroll_fee: u256 = 0;

    // Create a free course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(name.clone(), instructor, enroll_fee);

    // Multiple students enroll
    cheat_caller_address(contract_address, student1, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    cheat_caller_address(contract_address, student2, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    cheat_caller_address(contract_address, student3, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Verify all enrollments
    let updated_course = dispatcher.get_course(course_id);
    assert(updated_course.total_enrolled == 3, 'Should have 3 enrolled students');

    assert(dispatcher.is_enrolled(course_id, student1), 'Student1 should be enrolled');
    assert(dispatcher.is_enrolled(course_id, student2), 'Student2 should be enrolled');
    assert(dispatcher.is_enrolled(course_id, student3), 'Student3 should be enrolled');
}

#[test]
#[should_panic(expected: 'Course does not exist')]
fn test_enroll_nonexistent_course() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let student: ContractAddress = contract_address_const::<'student'>();

    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(999, 0); // Non-existent course ID
}

#[test]
#[should_panic(expected: 'Already enrolled in course')]
fn test_double_enrollment() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

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

#[test]
fn test_multiple_free_courses() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let instructor1: ContractAddress = contract_address_const::<'instructor1'>();
    let instructor2: ContractAddress = contract_address_const::<'instructor2'>();
    let student: ContractAddress = contract_address_const::<'student'>();

    // Create two free courses
    cheat_caller_address(contract_address, instructor1, CheatSpan::Indefinite);
    let course_id1 = dispatcher.create_course("Course 1", instructor1, 0);

    cheat_caller_address(contract_address, instructor2, CheatSpan::Indefinite);
    let course_id2 = dispatcher.create_course("Course 2", instructor2, 0);

    // Student enrolls in both courses
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id1, 0);
    dispatcher.enroll_for_course(course_id2, 0);

    // Verify enrollments
    assert(dispatcher.is_enrolled(course_id1, student), 'student enrolled in course 1');
    assert(dispatcher.is_enrolled(course_id2, student), 'student enrolled in course 2');

    let course1 = dispatcher.get_course(course_id1);
    let course2 = dispatcher.get_course(course_id2);

    assert(course1.total_enrolled == 1, 'Course 1 should have 1 student');
    assert(course2.total_enrolled == 1, 'Course 2 should have 1 student');
}

#[test]
fn test_get_payment_token() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let dummy_token_address: ContractAddress = contract_address_const::<'dummy_token'>();
    let retrieved_token = dispatcher.get_payment_token();

    assert(retrieved_token == dummy_token_address, 'Payment token address mismatch');
}

#[test]
fn test_set_payment_token() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    let new_token_address: ContractAddress = contract_address_const::<'new_token'>();

    // Set new payment token
    dispatcher.set_payment_token(new_token_address);

    // Verify it was set
    let retrieved_token = dispatcher.get_payment_token();
    assert(retrieved_token == new_token_address, 'New payment token not set');
}

#[test]
fn test_issue_certificate() {
    // Deploy contract
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Setup test data
    let instructor = contract_address_const::<'instructor'>();
    let student = contract_address_const::<'student'>();
    let course_name = "Test Course";
    let metadata_uri = "ipfs://QmTest";

    // Create course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(course_name, instructor, 0);

    // Enroll student
    cheat_caller_address(contract_address, student, CheatSpan::Indefinite);
    dispatcher.enroll_for_course(course_id, 0);

    // Issue certificate
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let certificate_id = dispatcher.issue_certificate(course_id, student, metadata_uri);

    // Verify certificate details
    let certificate = dispatcher.get_certificate(certificate_id);
    assert(certificate.id == certificate_id, 'Invalid certificate id');
    assert(certificate.course_id == course_id, 'Invalid course id');
    assert(certificate.student == student, 'Invalid student');
}

#[test]
#[should_panic(expected: ('Only instructor can issue',))]
fn test_issue_certificate_unauthorized() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Setup test data
    let instructor = contract_address_const::<'instructor'>();
    let student = contract_address_const::<'student'>();
    let unauthorized = contract_address_const::<'unauthorized'>();
    let course_name = "Test Course";
    let metadata_uri = "ipfs://QmTest";

    // Create course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(course_name, instructor, 0);

    // Try to issue certificate as unauthorized user
    cheat_caller_address(contract_address, unauthorized, CheatSpan::Indefinite);
    dispatcher.issue_certificate(course_id, student, metadata_uri);
}

#[test]
#[should_panic(expected: ('Student not enrolled',))]
fn test_issue_certificate_not_enrolled() {
    let contract_address = setup();
    let dispatcher = IAuralexDispatcher { contract_address };

    // Setup test data
    let instructor = contract_address_const::<'instructor'>();
    let student = contract_address_const::<'student'>();
    let course_name = "Test Course";
    let metadata_uri = "ipfs://QmTest";

    // Create course
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    let course_id = dispatcher.create_course(course_name, instructor, 0);

    // Try to issue certificate without enrollment
    cheat_caller_address(contract_address, instructor, CheatSpan::Indefinite);
    dispatcher.issue_certificate(course_id, student, metadata_uri);
}

