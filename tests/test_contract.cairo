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
