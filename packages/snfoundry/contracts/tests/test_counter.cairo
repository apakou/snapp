use starknet::ContractAddress;
use snforge_std::{ declare, ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, spy_events, start_cheat_caller_address, stop_cheat_caller_address };
use contracts::counter::{ ICounterDispatcher, ICounterDispatcherTrait };
use contracts::counter::CounterContract::{ CounterChanged, CounterDecreased, CounterIncreased, Event };


fn owner_address() -> ContractAddress {
    'owner'.try_into().unwrap()
}

fn user_address() -> ContractAddress {
    'user'.try_into().unwrap()
}

fn deploy_counter(init_counter: u32) -> ICounterDispatcher{
    let contract = declare("CounterContract").unwrap().contract_class();

    let owner_address: ContractAddress = owner_address();

    let mut constructor_args = array![];
    init_counter.serialize(ref constructor_args);
    owner_address.serialize(ref constructor_args);

    let (contract_address, _) = contract.deploy(@constructor_args).unwrap();
    ICounterDispatcher{ contract_address }
}

#[test]
fn test_contract_initialization() {
    let dispatcher = deploy_counter(5);
    let current_counter = dispatcher.get_counter();
    let expected_counter:u32 = 5;
    assert!(current_counter == expected_counter, "Counter should be initialized to 5")
}

#[test]
fn test_increase_counter() {
    let init_counter: u32 = 0;
    let dispatcher = deploy_counter(init_counter);
    let mut spy = spy_events();

    start_cheat_caller_address(dispatcher.contract_address, user_address());
    dispatcher.increase_counter();
    stop_cheat_caller_address(dispatcher.contract_address);

    let current_counter: u32 = dispatcher.get_counter();

    assert!(current_counter == 1, "Counter should be increased by 1");

    let expected_event = CounterIncreased {
        caller: user_address(),
        new_value: current_counter
    };

    spy.assert_emitted(@array![(
        dispatcher.contract_address,
        Event::CounterIncreased(expected_event)
    )])
}

#[test]
fn test_decrease_counter() {
    let init_counter: u32 = 1;
    let dispatcher = deploy_counter(init_counter);
    let mut spy = spy_events();

    start_cheat_caller_address(dispatcher.contract_address, user_address());
    dispatcher.decrease_counter();
    stop_cheat_caller_address(dispatcher.contract_address);

    let current_counter: u32 = dispatcher.get_counter();

    assert!(current_counter == 0, "Counter should be decreased by 1");

    let expected_event = CounterDecreased {
        caller: user_address(),
        new_value: current_counter
    };

    spy.assert_emitted(@array![(
        dispatcher.contract_address,
        Event::CounterDecreased(expected_event)
    )])
}

#[test]
#[should_panic]
fn test_decrease_counter_fail_path() {
    let init_counter: u32 = 0;
    let dispatcher = deploy_counter(init_counter);

    dispatcher.decrease_counter();
    dispatcher.get_counter();
}
