#[starknet::interface]
pub trait ICounter<T> {
    fn get_counter(self: @T) -> u32;
    fn increase_counter(ref self: T);
    fn decrease_counter(ref self: T);
    fn set_counter(ref self: T, new_value: u32);
    fn reset_counter(ref self: T);
}

#[starknet::contract]
pub mod CounterContract {
    use OwnableComponent::InternalTrait;
    use super::ICounter;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{get_caller_address, get_contract_address, ContractAddress};
    use openzeppelin_access::ownable::OwnableComponent;
    use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use contracts::utils::{ strk_address, strk_to_fri };

    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);

    #[abi(embed_v0)]
    impl OwnableImpl = OwnableComponent::OwnableImpl<ContractState>;
    impl InternalImpl = OwnableComponent::InternalImpl<ContractState>;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        CounterIncreased: CounterIncreased,
        CounterDecreased: CounterDecreased,
        CounterChanged: CounterChanged,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CounterIncreased {
        #[key]
        pub caller: ContractAddress,
        pub new_value: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CounterDecreased {
        #[key]
        pub caller: ContractAddress,
        pub new_value: u32,
    }

    #[derive(Drop, starknet::Event)]
    pub struct CounterChanged {
        #[key]
        pub caller: ContractAddress,
        pub old_value: u32,
        pub new_value: u32,
    }

    #[storage]
    struct Storage {
        counter: u32,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState, init_value: u32, owner: ContractAddress) {
        self.counter.write(init_value);
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl CounterImpl of ICounter<ContractState> {
        fn get_counter(self: @ContractState) -> u32 {
            self.counter.read()
        }

        fn increase_counter(ref self: ContractState) {
            let current_value = self.counter.read();
            self.counter.write(current_value + 1);

            let event: CounterIncreased = CounterIncreased {
                caller: get_caller_address(),
                new_value: current_value + 1,
            };

            self.emit(event);
        }

        fn decrease_counter(ref self: ContractState) {
            let current_value = self.counter.read();
            assert!(current_value > 0, "Counter cannot be negative");
            self.counter.write(current_value - 1);

            let event: CounterDecreased = CounterDecreased {
                caller: get_caller_address(),
                new_value: current_value - 1,
            };

            self.emit(event);
        }

        fn set_counter(ref self: ContractState, new_value: u32) {
            self.ownable.assert_only_owner();
            let old_counter = self.counter.read();
            self.counter.write(new_value);
            let event: CounterChanged = CounterChanged {
                caller: get_caller_address(),
                old_value: old_counter,
                new_value: new_value,
            };

            self.emit(event);
        }

        fn reset_counter(ref self: ContractState) {
            let payment_amount: u256 = strk_to_fri(1);
            let strk_token: ContractAddress = strk_address();
            
            let caller = get_caller_address();
            let contract = get_contract_address();
            let dispatcher = IERC20Dispatcher { contract_address: strk_token };

            let balance = dispatcher.balance_of(caller);
            assert!(balance >= payment_amount, "Insufficient STRK balance to reset counter");

            let allowance = dispatcher.allowance(caller, contract);
            assert!(allowance >= payment_amount, "Insufficient STRK allowance to reset counter");

            let owner = self.ownable.owner();
            let success: bool = dispatcher.transfer_from(caller, owner, payment_amount);
            assert!(success, "STRK transfer failed");

            let old_counter = self.counter.read();
            self.counter.write(0);
            
            let event: CounterChanged = CounterChanged {
                caller: get_caller_address(),
                old_value: old_counter,
                new_value: 0,
            };

            self.emit(event);
        }
    }
} 