// Import libraries
use contracts::Counter::Counter::FELT_STRK_CONTRACT;
use contracts::Counter::{
    Counter, ICounterDispatcher, ICounterDispatcherTrait, ICounterSafeDispatcher, ICounterSafeDispatcherTrait};
use core::traits::TryInto;
use openzeppelin_access::ownable::interface::{IOwnableDispatcher, IOwnableDispatcherTrait};
use openzeppelin_token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
use snforge_std::{
    ContractClassTrait, DeclareResultTrait, EventSpyAssertionsTrait, declare, spy_events,
    start_cheat_caller_address, stop_cheat_caller_address
};
use starknet::{ContractAddress};

// Test account for owner
fn owner() -> ContractAddress {
    'owner'.try_into().unwrap()
}

// Test account for a user
fn user() -> ContractAddress {
    'user'.try_into().unwrap()
}

fn strk_token_contract() -> ContractAddress {
    FELT_STRK_CONTRACT.try_into().unwrap()
}

// ByBit wallet to use in the Mainnet Fork test
pub const STRK_TOKEN_HOLDER_ADDRESS: felt252 =
    0x076601136372fcdbbd914eea797082f7504f828e122288ad45748b0c8b0c9696;

fn strk_token_holder() -> ContractAddress {
    STRK_TOKEN_HOLDER_ADDRESS.try_into().unwrap()
}

fn get_strk_token_balance(account: ContractAddress) -> u256 {
    IERC20Dispatcher {contract_address: strk_token_contract()}.balance_of(account)
}

fn strk_transfer(caller: ContractAddress, recipient: ContractAddress, amount: u256) {
    start_cheat_caller_address(strk_token_contract(), caller);
    let token_dispatcher = IERC20Dispatcher { contract_address: strk_token_contract()};
    token_dispatcher.transfer(recipient, amount);
    stop_cheat_caller_address(strk_token_contract());
}

fn strk_approve(owner: ContractAddress, spender: ContractAddress, amount: u256) {
    start_cheat_caller_address(strk_token_contract(), owner);
    let token_dispatcher = IERC20Dispatcher { contract_address: strk_token_contract()};
    token_dispatcher.approve(spender, amount);
    stop_cheat_caller_address(strk_token_contract());
}

const WIN_NUMBER: u32 = 5;
const decimals: u256 = 1000000000000000000_u256;

// Deploy function
fn __deploy__(
    init_value: u32, init_strk_amount: u256,
) -> (ICounterDispatcher, IOwnableDispatcher, ICounterSafeDispatcher, IERC20Dispatcher) {
    // declare a contract class
    let contract_class = declare("Counter").expect('failed to declare class').contract_class();
    let strk_token = IERC20Dispatcher { contract_address: strk_token_contract()};

    // Serialize the constructor
    let mut calldata: Array<felt252> = array![];
    init_value.serialize(ref calldata);
    owner().serialize(ref calldata);

    // Deploy the contract
    let (counter_contract_address, _) = contract_class.deploy(@calldata).expect('failed to deploy');

    // Get a Counter instance
    let counter = ICounterDispatcher { contract_address: counter_contract_address };
    let ownable = IOwnableDispatcher { contract_address: counter_contract_address };
    let safe_counter = ICounterSafeDispatcher { contract_address: counter_contract_address };

    // Calculate decimals: 10^18
    let init_strk_amount_decimals = init_strk_amount * decimals;

    strk_transfer(strk_token_holder(), counter_contract_address, init_strk_amount_decimals);

    (counter, ownable, safe_counter, strk_token)
}

// Test that the contract deploys successfully
#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_counter_deployment() {
    let (counter, ownable, _, _) = __deploy__(0, 0);
    let counter_value = counter.get_counter();
    assert(counter_value == 0, 'Counter not set');
    assert(ownable.owner() == owner(), 'Owner not set');
}

// Test the increase_counter function
#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_increase_counter() {
    let init_value = 0;
    let (counter, _, _, _) = __deploy__(init_value, 5);
    let initial_counter_value = counter.get_counter();

    assert(initial_counter_value == 0, 'Counter not set');

    // We now call increase_counter()
    counter.increase_counter();

    // Retrieve the updated counter_value
    let updated_counter_value = counter.get_counter();

    // Asserts that that initial_counter_value is increased by 1
    assert(updated_counter_value == initial_counter_value + 1, 'Counter has not increased');
}

// Test the normal decrease function (not considering the counter at zero when decreasing)
#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_normal_decrease_counter() {
    let init_value = 4;
    let (counter, _, _, _) = __deploy__(init_value, 5);
    let initial_counter_value = counter.get_counter();

    assert(initial_counter_value == 4, 'Counter not well set');

    // We now call decrease_counter()
    counter.decrease_counter();

    // Retrieve the updated counter_value
    let updated_counter_value = counter.get_counter();

    // Asserts that that initial_counter_value is decreased by 1
    assert(updated_counter_value == initial_counter_value - 1, 'Counter has not decreased');
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_emitted_increased_event() {
    let init_value = 0;
    let (counter, _, _, _) = __deploy__(init_value, 5);

    // Get the spy event before calling the function
    let mut spy = spy_events();

    // Mimick a caller
    start_cheat_caller_address(counter.contract_address, user());

    // Call the increase_counter function
    counter.increase_counter();
    //Stop the cheat caller address
    stop_cheat_caller_address(counter.contract_address);

    // Checking if Increased event is emitted for user() account

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Increased(Counter::Increased { account: user() }),
                ),
            ],
        );

    // Just a side check to show that we can show an assert_not_emitted
    spy
        .assert_not_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: user() }),
                ),
            ],
        );
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_emitted_decreased_event() {
    let init_value = 5;
    let (counter, _, _, _) = __deploy__(init_value, 5);

    // Get the spy event before calling the function
    let mut spy = spy_events();

    // Mimick a caller
    start_cheat_caller_address(counter.contract_address, user());

    // Call the increase_counter function
    counter.decrease_counter();
    //Stop the cheat caller address
    stop_cheat_caller_address(counter.contract_address);

    // Checking if Decreased event is emitted for user() account

    spy
        .assert_emitted(
            @array![
                (
                    counter.contract_address,
                    Counter::Event::Decreased(Counter::Decreased { account: user() }),
                ),
            ],
        );
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
#[feature("safe_dispatcher")]
fn test_safe_panic_decrease_counter() {
    // Deploy the Counter contract and initialize the counter value to zero
    let (counter, _, safe_counter, _) = __deploy__(0, 5);

    assert(counter.get_counter() == 0, 'Invalid initial value');

    start_cheat_caller_address(counter.contract_address, user());


    match safe_counter.decrease_counter() {
        Result::Ok(_) => panic!("Cannot decrease the counter below zero"),
        Result::Err(error) => assert(*error[0] == 'Decreasing Empty counter', *error.at(0)),
    }
    stop_cheat_caller_address(counter.contract_address);

}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
#[should_panic(expected: 'Decreasing Empty counter')]
fn test_panic_decrease_counter() {
    // Deploy the Counter contract and initialize the counter value to zero
    let (counter, _, _, _) = __deploy__(0, 5);

    assert(counter.get_counter() == 0, 'Invalid initial value');
    counter.decrease_counter();
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_reset_counter_with_reset_event_emitted() {
    let init_value = 3;
    let STRK_contract_balance = 10;
    let STRK_contract_balance_decimals = STRK_contract_balance * decimals;
    let user = user();
    let strk_token_holder = strk_token_holder();

    // We initialize the Counter contract with a value of 3 and 10 STRKs.
    let (counter, _, _, strk_token) = __deploy__(init_value, STRK_contract_balance);
    assert(counter.get_counter() == 3, 'Invalid initial value');
    assert(get_strk_token_balance(counter.contract_address) == STRK_contract_balance_decimals, 'Initial contract has tokens');

    // We first check that the token_holder has sufficient STRKs
    assert(get_strk_token_balance(strk_token_holder) >= STRK_contract_balance_decimals, 'Token holder lacks funds');

    // Generous STRK transfer from token_holder to user to pay for reset
    // User starts with zero STRK tokens
    assert(get_strk_token_balance(user) == 0, 'User has tokens intially');

    // The token holder then transfers 10 + 7 =  17 STRK tokens to the user
    strk_transfer(strk_token_holder, user, STRK_contract_balance_decimals + (7 * decimals));
    let user_balance_decimals = STRK_contract_balance_decimals + (7 * decimals);
    // User gets "user_balance_decimals" STRKs from token holder
    assert(get_strk_token_balance(user) == user_balance_decimals, 'User does not have tokens');

    // User approves token transfers for the user.
    strk_approve(user, counter.contract_address, user_balance_decimals);

    //We check if the allowance for the user is present
    let counter_allowance = strk_token.allowance(user, counter.contract_address);
    assert(counter_allowance >= STRK_contract_balance_decimals, 'Insufficient STRKs');

    // Get the spy event before calling the function
    let mut spy = spy_events();

    // Mimicks the user resetting the Counter
    start_cheat_caller_address(counter.contract_address, user);
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    // We reset the Counter to zero
    assert(counter.get_counter() == 0, 'Counter was not reset');

    // The balance of the user goes from 17 STRK tokens to 7 STRK tokens (10 STRK pays for the reset)
    assert(get_strk_token_balance(user) == user_balance_decimals - STRK_contract_balance_decimals, 'User still have tokens');

    // The balance of the Counter contract doubles!
    assert(get_strk_token_balance(counter.contract_address) == 2 * STRK_contract_balance_decimals, 'Contract tokens has not doubled');

    spy
    .assert_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Reset(Counter::Reset { account: user }),
            ),
        ],
    );
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_reset_counter_with_reset_event_emitted_with_contract_balance_at_zero() {
    let init_value = 3;
    let STRK_contract_balance = 0;
    let STRK_contract_balance_decimals = STRK_contract_balance * decimals;
    let desired_user_balance = 15;
    let desired_user_balance_decimals = desired_user_balance * decimals;
    let user = user();
    let strk_token_holder = strk_token_holder();

    // We initialize the Counter contract with a value of 3 and 0 STRK.
    let (counter, _, _, strk_token) = __deploy__(init_value, STRK_contract_balance);
    assert(counter.get_counter() == 3, 'Invalid initial value');
    assert(get_strk_token_balance(counter.contract_address) == 0, 'Initial contract has tokens');

    // We first check that the token_holder has sufficient STRKs to transfer to the user
    assert(get_strk_token_balance(strk_token_holder) >= desired_user_balance_decimals, 'Token holder lacks funds');

    // User starts with zero STRK tokens
    assert(get_strk_token_balance(user) == 0, 'User has tokens intially');

    // The token holder then transfers 15 STRKs to the user
    strk_transfer(strk_token_holder, user, desired_user_balance_decimals);
    assert(get_strk_token_balance(user) == desired_user_balance_decimals, 'User does not have tokens');

    // User approves token transfers for the user.
    strk_approve(user, counter.contract_address, desired_user_balance_decimals);

    // We check if the allowance for the user is present. 
    // At this point, the user has all the funds to pay if required
    let counter_allowance = strk_token.allowance(user, counter.contract_address);
    assert(counter_allowance >= STRK_contract_balance_decimals, 'Insufficient STRKs');

    // Get the spy event before calling the function
    let mut spy = spy_events();

    // Mimicks the user resetting the Counter
    start_cheat_caller_address(counter.contract_address, user);
    counter.reset_counter();
    stop_cheat_caller_address(counter.contract_address);

    // We reset the Counter to zero
    assert(counter.get_counter() == 0, 'Counter was not reset');

    // The balance of the user stays the same at 15 STRK tokens since NO payment is made to reset the Counter (free reset)
    assert(get_strk_token_balance(user) == desired_user_balance_decimals, 'User balance incorrect');

    // The balance of the Counter contract also stays the same at zero
    assert(get_strk_token_balance(counter.contract_address) == 0, 'Contract has tokens');

    spy
    .assert_emitted(
        @array![
            (
                counter.contract_address,
                Counter::Event::Reset(Counter::Reset { account: user }),
            ),
        ],
    );
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_transfers_strk_from_counter_contract_to_winner() {
    // Deploy the counter contract with counter initialized to one short of the winning number
    // We also initialize the counter contract with 5 STRK tokens.
    let strk_amount = 5;
    let strk_amount_decimals = strk_amount * decimals;
    let (counter, _, _, _) = __deploy__(WIN_NUMBER - 1, strk_amount);
    let user = user();

    let initial_counter = counter.get_counter();
    assert(initial_counter == WIN_NUMBER - 1, 'Counter wrongly set');

    // The initial balance of the Counter contract is 5 STRKs.
    let initial_counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(initial_counter_strk_balance == strk_amount_decimals, 'Invalid Counter balance');

    // The initial balance of the user is 0 STRKs.
    let initial_user_strk_balance = get_strk_token_balance(user);
    assert(initial_user_strk_balance == 0, 'Invalid initial user balance');

    // Let the user call increase_counter()
    start_cheat_caller_address(counter.contract_address, user);
    counter.increase_counter();
    stop_cheat_caller_address(strk_token_contract());

    // Assert that the WIN_NUMBER has been reached
    assert(counter.get_counter() == WIN_NUMBER, 'Win Number not reached');

    // After the call, user is the winner. Therefore contract balance should be zero.
    let final_counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(final_counter_strk_balance == 0, 'Contract did not transfer STRK');

    // After the call, the contract balance is depleted and sent to the user. 
    // The latter should now have the 5 STRKs.
    let final_user_strk_balance = get_strk_token_balance(user);    
    assert(final_user_strk_balance == strk_amount_decimals, 'Winner did not receive STRK');
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_no_strk_transfers_for_winner_when_contract_has_no_tokens() {
    // Deploy the counter contract with counter initialized to one short of the winning number
    // We also initialize the counter contract with 0 STRK tokens.
    let strk_amount = 0;
    let strk_amount_decimals = strk_amount * decimals;
    let initial_user_strk_amount = 3;
    let initial_user_strk_amount_decimals = initial_user_strk_amount * decimals;
    let (counter, _, _, _) = __deploy__(WIN_NUMBER - 1, strk_amount);
    let user = user();
    let strk_token_holder = strk_token_holder();

    let initial_counter = counter.get_counter();
    assert(initial_counter == WIN_NUMBER - 1, 'Counter wrongly set');

    // The initial balance of the Counter contract is 0 STRKs.
    let initial_counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(initial_counter_strk_balance == strk_amount_decimals, 'Invalid Counter balance');

    // We assert that the very initial user STRK balance is zero.
    assert(get_strk_token_balance(user) == 0, 'Initial user balance not zero');

    // next, we transfer 3 STRK tokens from the token holder to the user
    strk_transfer(strk_token_holder, user, initial_user_strk_amount_decimals);
    let initial_user_strk_balance = get_strk_token_balance(user);
    assert(initial_user_strk_balance == initial_user_strk_amount_decimals, 'Invalid initial user balance');

    // Let the user call increase_counter()
    start_cheat_caller_address(counter.contract_address, user);
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    // Assert that the WIN_NUMBER has been reached
    assert(counter.get_counter() == WIN_NUMBER, 'Win Number not reached');

    // After the call, user is the winner. However the contract still has no tokens.
    let final_counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(final_counter_strk_balance == 0, 'Contract should have 0 STRK');

    // After the call, the user should have the same number of tokens, i.e 3 STRKs, i.e. no funds transferred from contract.
    let final_user_strk_balance = get_strk_token_balance(user);    
    assert(final_user_strk_balance == initial_user_strk_balance, 'Winner STRK balance has changed');
}

#[test]
#[fork("MAINNET_LATEST", block_tag: latest)]
fn test_two_increase_steps_and_win() {
    // Deploy the counter contract with counter initialized to two shorts of the winning number
    // We also initialize the counter contract with 5 STRK tokens.
    let strk_amount = 5;
    let strk_amount_decimals = strk_amount * decimals;
    let (counter, _, _, _) = __deploy__(WIN_NUMBER - 2, strk_amount);
    let user = user();
    let owner = owner();
    let strk_token_holder = strk_token_holder();

    let initial_counter = counter.get_counter();
    assert(initial_counter == WIN_NUMBER - 2, 'Counter wrongly set');

    // The initial balance of the Counter contract is 5 STRKs.
    let initial_counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(initial_counter_strk_balance == strk_amount_decimals, 'Invalid Counter balance');

    // The initial balance of the user and owner is 0 STRKs.
    let initial_user_strk_balance = get_strk_token_balance(user);
    assert(initial_user_strk_balance == 0, 'Invalid initial user balance');

    let initial_owner_strk_balance = get_strk_token_balance(owner);
    assert(initial_owner_strk_balance == 0, 'Invalid initial owner balance');

    let strk_token_holder_balance = get_strk_token_balance(strk_token_holder);
    assert(strk_token_holder_balance >= 18 * decimals, 'Token holder with no funds');

     // The token holder then transfers 8 STRKs to the user and 10 STRKs to the owner
     strk_transfer(strk_token_holder, user, 8 * decimals);
     assert(get_strk_token_balance(user) == 8 * decimals, 'User does not have 8 STRKs');
     strk_transfer(strk_token_holder, owner, 10 * decimals);
     assert(get_strk_token_balance(owner) == 10 * decimals, 'User does not have 10 STRKs');
 

    // Let the user call increase_counter() with 2 STRKs. One step to win
    start_cheat_caller_address(counter.contract_address, user);
    strk_transfer(user, counter.contract_address, 2 * decimals);
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    assert(counter.get_counter() == WIN_NUMBER - 1, 'Win Number - 1 not reached');

    // Let the owner call increase_counter() with 1 STRK and win.
    start_cheat_caller_address(counter.contract_address, owner);
    strk_transfer(owner, counter.contract_address, 1 * decimals);
    counter.increase_counter();
    stop_cheat_caller_address(counter.contract_address);

    // Assert that the WIN_NUMBER has been reached
    assert(counter.get_counter() == WIN_NUMBER, 'Win Number not reached');

    // After the call, the contract balance should go to zero
    let final_counter_strk_balance = get_strk_token_balance(counter.contract_address);
    assert(final_counter_strk_balance == 0, 'Contract did not transfer STRK');

    // After the call, the user should have 2 STRKs less.
    let final_user_strk_balance = get_strk_token_balance(user);    
    assert(final_user_strk_balance == (8 - 2) * decimals, 'User STRK amount not correct');

    // After the call, the owner should 10 STRKs + 5 STRKs from the initial contract + 2 STRKs from the user.
    let final_owner_strk_balance = get_strk_token_balance(owner);    
    assert(final_owner_strk_balance == (10 + 5 + 2) * decimals, 'Owner STRK amount not correct');
}
