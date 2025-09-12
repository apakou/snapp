use starknet::ContractAddress;
use snforge_std::{ 
    declare, 
    ContractClassTrait, 
    DeclareResultTrait, 
    EventSpyAssertionsTrait, 
    spy_events, 
    start_cheat_caller_address, 
    stop_cheat_caller_address,
    set_balance,
    Token
};
use contracts::counter::{ ICounterDispatcher, ICounterDispatcherTrait };
use contracts::counter::CounterContract::{ 
    CounterChanged, 
    CounterDecreased, 
    CounterIncreased, 
    Event 
};
use contracts::utils::{ strk_address, strk_to_fri };
use openzeppelin_token::erc20::interface::{ IERC20Dispatcher, IERC20DispatcherTrait };


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

#[test]
fn test_set_counter_owner() {
    let init_counter: u32 = 8;
    let dispatcher = deploy_counter(init_counter);
    let mut spy = spy_events();
    let new_value: u32 = 15;

    start_cheat_caller_address(dispatcher.contract_address, owner_address());
    dispatcher.set_counter(new_value);
    stop_cheat_caller_address(dispatcher.contract_address);

    assert!(dispatcher.get_counter() == new_value, "Counter should be reset to 0 by user");

    let expected_event = CounterChanged {
        caller: owner_address(),
        old_value: init_counter,
        new_value: new_value
    };

    spy.assert_emitted(@array![(
        dispatcher.contract_address,
        Event::CounterChanged(expected_event)
    )])
}

#[test]
#[should_panic]
fn test_set_counter_not_owner() {
    let init_counter: u32 = 8;
    let dispatcher = deploy_counter(init_counter);
    let new_value: u32 = 15;

    start_cheat_caller_address(dispatcher.contract_address, user_address());
    dispatcher.set_counter(new_value);
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: "Insufficient STRK balance to reset counter")]
fn test_reset_counter_insufficient_balance() {
    let init_counter: u32 = 8;
    let dispatcher = deploy_counter(init_counter);

    start_cheat_caller_address(dispatcher.contract_address, user_address());
    dispatcher.reset_counter();
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
#[should_panic(expected: "Insufficient STRK allowance to reset counter")]
fn test_reset_counter_insufficient_allowance() {
    let init_counter: u32 = 8;
    let dispatcher = deploy_counter(init_counter);
    let caller = user_address();

    set_balance(caller, strk_to_fri(10), Token::STRK);

    start_cheat_caller_address(dispatcher.contract_address, user_address());
    dispatcher.reset_counter();
    stop_cheat_caller_address(dispatcher.contract_address);
}

#[test]
fn test_reset_counter_success() {
    let init_counter: u32 = 8;
    let counter = deploy_counter(init_counter);
    let user = user_address();
    let mut spy = spy_events();

    set_balance(user, strk_to_fri(10), Token::STRK);
    let erc20 = IERC20Dispatcher { contract_address: strk_address() };
    
    start_cheat_caller_address(erc20.contract_address, user);
    erc20.approve(counter.contract_address, strk_to_fri(10));
    stop_cheat_caller_address(erc20.contract_address);
    
    start_cheat_caller_address(counter.contract_address, user);
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    assert!(counter.get_counter() == 0, "Counter should be reset to 0 by user");

    let expected_event = CounterChanged {
        caller: user,
        old_value: init_counter,
        new_value: 0
    };

    spy.assert_emitted(@array![(
        counter.contract_address,
        Event::CounterChanged(expected_event)
    )]);

    assert!(erc20.balance_of(user) == strk_to_fri(9), "User STRK balance should be deducted by 1 STRK");
    assert!(erc20.balance_of(owner_address()) == strk_to_fri(1), "Owner STRK balance should be increased by 1 STRK");
}