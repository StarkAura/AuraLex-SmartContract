use starknet::ContractAddress;

#[starknet::interface]
pub trait IAuralex<TContractState> {
    // Courses
    fn create_course(ref self: TContractState, course_details: ByteArray) -> u256;
    fn enroll_for_course(ref self: TContractState, course_id: u256, fee: u256);
    fn mint_course_certificate(ref self: TContractState, course_id: u256);
    fn verify_course_credential(self: @TContractState, course_id: u256, student: ContractAddress);
}
