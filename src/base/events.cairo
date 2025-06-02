use core::serde::Serde;
use starknet::ContractAddress;

#[derive(Drop, starknet::Event)]
pub struct StudentEnrolled {
    #[key]
    pub course_id: u256,
    #[key]
    pub student: ContractAddress,
    pub fee_paid: u256,
    pub enrolled_at: u64,
}

#[derive(Drop, starknet::Event)]
pub struct PaymentProcessed {
    #[key]
    pub course_id: u256,
    #[key]
    pub from: ContractAddress,
    #[key]
    pub to: ContractAddress,
    pub amount: u256,
    pub token_address: ContractAddress,
}
