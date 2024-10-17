use core::poseidon::PoseidonTrait;
use core::hash::{HashStateTrait, HashStateExTrait};
use overdrive::models::game_models::{CipherTypes, Cipher, GamePlayer};
use overdrive::constants;
use starknet::get_block_timestamp;

pub fn hash2(val_1: felt252, val_2: felt252) -> felt252 {
    let mut hash = PoseidonTrait::new();

    hash = hash.update(val_1);
    hash = hash.update(val_2);

    hash.finalize()
}

pub fn hash4(val_1: felt252, val_2: felt252, val_3: felt252, val_4: felt252) -> felt252 {
    let mut hash = PoseidonTrait::new();

    hash = hash.update(val_1);
    hash = hash.update(val_2);
    hash = hash.update(val_3);
    hash = hash.update(val_4);

    hash.finalize()
}

pub fn get_range(value: u256, min: u256, max: u256) -> u256 {
    min + (value % (max - min + 1))
}

pub fn parse_cipher_type(cipher_type: u8) -> CipherTypes {
    match cipher_type {
        0 => CipherTypes::Advance,
        1 => CipherTypes::Attack,
        2 => CipherTypes::Energy,
        3 => CipherTypes::Shield,
        _ => { CipherTypes::Unknown }
    }
}

pub fn calc_energy_regen(ref player: GamePlayer) -> () {
    let current_time = get_block_timestamp();
    let time_since_action: u64 = current_time - player.last_action_timestamp;

    let energy_regenerated: u64 = time_since_action / constants::REGEN_EVERY.into();
    let reminder_seconds: u64 = time_since_action % constants::REGEN_EVERY.into();

    player.energy = if (player.energy + energy_regenerated.into() > 10) {
        10
    } else {
        player.energy + energy_regenerated.into()
    };

    player.last_action_timestamp = current_time - reminder_seconds;
}

pub fn get_cipher_stats(ciphers: Array<Cipher>) -> (u8, CipherTypes) {
    let mut cipher_total_value: u8 = 0;
    let mut cipher_total_type = CipherTypes::Unknown;

    // Check for max combo
    if (ciphers.len() == 3
        && ciphers[0].cipher_type == ciphers[1].cipher_type
        && ciphers[0].cipher_type == ciphers[2].cipher_type) {
        cipher_total_value = (*ciphers[0].cipher_value + *ciphers[1].cipher_value + *ciphers[2].cipher_value) * 2;
        cipher_total_type = *ciphers[0].cipher_type;
    } else {
        // Check if at least there are two equal types
        if (ciphers.len() == 2 && ciphers[0].cipher_type == ciphers[1].cipher_type) {
            cipher_total_value = *ciphers[0].cipher_value + *ciphers[1].cipher_value;
            cipher_total_type = *ciphers[0].cipher_type;
        }
        if (ciphers.len() == 3 && ciphers[0].cipher_type == ciphers[2].cipher_type) {
            cipher_total_value = *ciphers[0].cipher_value + *ciphers[2].cipher_value;
            cipher_total_type = *ciphers[0].cipher_type;
        }
        if (ciphers.len() == 3 && ciphers[1].cipher_type == ciphers[2].cipher_type) {
            cipher_total_value = *ciphers[1].cipher_value + *ciphers[2].cipher_value;
            cipher_total_type = *ciphers[1].cipher_type;
        }
    }

    (cipher_total_value, cipher_total_type)
}

pub fn handle_cipher_action(
    ref player: GamePlayer, 
    ref opponent: GamePlayer, 
    cipher_total_type: CipherTypes, 
    cipher_total_value: u8
) -> () {
    match cipher_total_type {
        CipherTypes::Advance => { 
            player.score += cipher_total_value.into();
            println!("Running advance {:?} {:?}", player.score, cipher_total_value);
            // TODO: Check for end game
        },
        CipherTypes::Attack => {
            let mut cipher_attack = if (opponent.shield > cipher_total_value.into()) {
                opponent.shield -= cipher_total_value.into();
                0
            } else {
                let shield = opponent.shield;
                opponent.shield = 0;
                cipher_total_value.into() - shield
            };

            if (opponent.score < cipher_attack) {
                opponent.score = 0;
            } else {
                opponent.score -= cipher_attack;
            }
        },
        CipherTypes::Shield => { player.shield += cipher_total_value.into(); },
        CipherTypes::Energy => { player.energy += cipher_total_value.into(); },
        _ => { assert(cipher_total_type == CipherTypes::Unknown, constants::UNKNOWN_CIPHER_TYPE); },
    }
}
