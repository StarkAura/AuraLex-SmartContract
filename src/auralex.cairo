#[starknet::contract]
pub mod Auralex {
    use auralex_contracts::base::events::{PaymentProcessed, StudentEnrolled};
    use auralex_contracts::base::types::{Certificate, CourseDetails, ResourceType};
    use auralex_contracts::interfaces::IAuralex::IAuralex;
    use auralex_contracts::interfaces::IErc20::{IERC20Dispatcher, IERC20DispatcherTrait};
    use starknet::storage::{
        Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess,
    };
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address};

    #[storage]
    struct Storage {
        // Course management
        courses: Map<u256, CourseDetails>,
        next_course_id: u256,
        // Course enrollments: course_id -> (student_address -> bool)
        course_enrollments: Map<(u256, ContractAddress), bool>,
        // Payment token address
        payment_token: ContractAddress,
        // Certificate NFT management
        certificates: Map<u256, Certificate>,
        next_certificate_id: u256,
        student_certificates: Map<
            (ContractAddress, u256), u256,
        > // student address -> course_id -> certificate_id
    }


    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        StudentEnrolled: StudentEnrolled,
        PaymentProcessed: PaymentProcessed,
        CertificateIssued: CertificateIssued,
    }

    #[derive(Drop, starknet::Event)]
    struct CertificateIssued {
        certificate_id: u256,
        course_id: u256,
        student: ContractAddress,
        issued_at: u64,
    }

    #[constructor]
    fn constructor(ref self: ContractState, payment_token_address: ContractAddress) {
        self.payment_token.write(payment_token_address);
        self.next_course_id.write(0);
    }


    #[abi(embed_v0)]
    impl AuralexImpl of IAuralex<ContractState> {
        fn create_course(
            ref self: ContractState, name: ByteArray, instructor: ContractAddress, enroll_fee: u256,
        ) -> u256 {
            // Get the current course ID
            let id = self.next_course_id.read() + 1; // Use it before incrementing
            let timestamp = get_block_timestamp();

            let mut course_type = ResourceType::Paid;
            if (enroll_fee == 0) {
                course_type = ResourceType::Free;
            }
            // Create a new course struct
            let new_course = CourseDetails {
                course_id: id,
                name,
                instructor,
                total_enrolled: 0,
                course_type: course_type,
                enroll_fee,
                updated_at: timestamp,
                created_at: timestamp,
            };

            // Store the course in the courses map
            self.courses.write(id, new_course);

            // Increment course ID and update storage **after** using it
            self.next_course_id.write(id);

            id
        }


        fn get_course(self: @ContractState, course_id: u256) -> CourseDetails {
            // Retrieve and return the course
            let course = self.courses.read(course_id);

            course
        }

        fn enroll_for_course(ref self: ContractState, course_id: u256, fee: u256) {
            let caller = get_caller_address();
            let current_timestamp = get_block_timestamp();

            // Check if course exists
            let next_id = self.next_course_id.read();
            assert(course_id > 0 && course_id <= next_id, 'Course does not exist');

            let mut course = self.courses.read(course_id);
            assert(course.course_id != 0, 'Course does not exist');

            // Check if already enrolled
            let is_enrolled = self.course_enrollments.read((course_id, caller));
            assert(!is_enrolled, 'Already enrolled in course');

            // Handle payment
            if course.course_type == ResourceType::Free {
                assert(fee == 0, 'Free course requires no fee');
            } else {
                assert(fee == course.enroll_fee, 'Incorrect enrollment fee');
                assert(fee > 0, 'Paid course requires fee');

                // Transfer ERC20 tokens
                let payment_token_address = self.payment_token.read();
                let token_dispatcher = IERC20Dispatcher { contract_address: payment_token_address };

                let caller_balance = token_dispatcher.balance_of(caller);
                assert(caller_balance.into() >= fee.into(), 'Insufficient token balance');

                let allowance: u256 = token_dispatcher
                    .allowance(caller, starknet::get_contract_address())
                    .into();
                assert(allowance >= fee, 'Insufficient token allowance');

                let fee_felt: felt252 = fee.try_into().unwrap();
                token_dispatcher.transfer_from(caller, course.instructor, fee_felt);

                // Emit payment processed event with all required fields
                self
                    .emit(
                        PaymentProcessed {
                            course_id,
                            from: caller,
                            to: course.instructor,
                            amount: fee,
                            token_address: payment_token_address,
                        },
                    );
            }

            // Enroll student
            self.course_enrollments.write((course_id, caller), true);
            course.total_enrolled += 1;
            course.updated_at = current_timestamp;
            self.courses.write(course_id, course);

            // Emit student enrolled event with all required fields
            self
                .emit(
                    StudentEnrolled {
                        course_id, student: caller, fee_paid: fee, enrolled_at: current_timestamp,
                    },
                );
        }
        fn is_enrolled(self: @ContractState, course_id: u256, student: ContractAddress) -> bool {
            self.course_enrollments.read((course_id, student))
        }

        fn get_payment_token(self: @ContractState) -> ContractAddress {
            self.payment_token.read()
        }

        fn set_payment_token(ref self: ContractState, new_token_address: ContractAddress) {
            self.payment_token.write(new_token_address);
        }

        fn issue_certificate(
            ref self: ContractState,
            course_id: u256,
            student: ContractAddress,
            metadata_uri: ByteArray,
        ) -> u256 {
            let caller = get_caller_address();
            let course = self.courses.read(course_id);

            // Verify caller is course instructor
            assert(caller == course.instructor, 'Only instructor can issue');

            // Verify student is enrolled
            assert(self.is_enrolled(course_id, student), 'Student not enrolled');

            // Check if certificate already issued
            let existing_cert = self.student_certificates.read((student, course_id));
            assert(existing_cert == 0, 'Certificate already issued');

            // Generate new certificate ID
            let certificate_id = self.next_certificate_id.read() + 1;
            self.next_certificate_id.write(certificate_id);

            let timestamp = get_block_timestamp();

            // Create certificate
            let certificate = Certificate {
                id: certificate_id, course_id, student, issued_at: timestamp, metadata_uri,
            };

            // Store certificate
            self.certificates.write(certificate_id, certificate);
            self.student_certificates.write((student, course_id), certificate_id);

            // Emit event
            self
                .emit(
                    CertificateIssued { certificate_id, course_id, student, issued_at: timestamp },
                );

            certificate_id
        }

        fn get_certificate(self: @ContractState, certificate_id: u256) -> Certificate {
            self.certificates.read(certificate_id)
        }
    }
}
