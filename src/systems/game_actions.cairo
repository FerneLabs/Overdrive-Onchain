use overdrive::models::{
    game_models::{Game, GamePlayer, GameTrait, GameMode, GameStatus, Cipher, CipherTypes}
};
use overdrive::utils;
use starknet::{ContractAddress, contract_address_const};

pub mod Errors {
    pub const ADDRESS_ZERO: felt252 = 'Cannot create from zero address';
    pub const USERNAME_TAKEN: felt252 = 'username already taken';
    pub const USERNAME_NOT_FOUND: felt252 = 'player with username not found';
    pub const USERNAME_EXIST: felt252 = 'username already exist';
    pub const ONLY_OWNER_USERNAME: felt252 = 'only user can update username';
    pub const UNKNOWN_CIPHER_TYPE: felt252 = 'cipher type is not valid';
}

#[dojo::interface]
trait IGameActions {
    fn create_game(ref world: IWorldDispatcher,);
    fn get_game_state(ref world: IWorldDispatcher, game_id: felt252);
    fn get_ciphers(ref world: IWorldDispatcher);
    fn set_player(
        ref world: IWorldDispatcher, ciphers: Array<Cipher>, player_address: ContractAddress
    );
    fn end_game(ref world: IWorldDispatcher, game_id: felt252);
}

#[dojo::contract]
mod gameActions {
    use super::Errors;
    use super::{
        IGameActions, Game, GamePlayer, GameMode, GameStatus, GameTrait, Cipher, CipherTypes, utils
    };
    use starknet::{
        ContractAddress, contract_address_const, SyscallResultTrait, get_caller_address,
        get_block_timestamp, get_block_number
    };
    use core::num::traits::Zero;

    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {
        fn create_game(ref world: IWorldDispatcher) {
            let zero_address = contract_address_const::<0x0>();
            let owner = get_caller_address();
            let game_id = world.uuid();

            // TODO: Handle user already playing - maybe add playing bool to account struct
            // let mut existing_account = get!(world, owner, (Account));
            // assert(existing_account.username == username, Errors::USERNAME_TAKEN);

            let (new_game, new_player_one, new_player_two) = GameTrait::new_single_player(
                game_id, owner, zero_address
            );
            println!("Created game with ID: {:?}", game_id);
            set!(world, (new_game, new_player_one, new_player_two));
        }

        fn get_game_state(ref world: IWorldDispatcher, game_id: felt252) {
            let game_id: usize = game_id.try_into().unwrap();
            let game = get!(world, game_id, (Game));

            let player_one = get!(world, game.player_1, (GamePlayer));
            let _player_two = get!(world, game.player_2, (GamePlayer));

            println!("GAME ID: {:?}", game.id);
            println!("GAME STATUS: {:?}", game.game_status);
            println!("GAME MODE: {:?}", game.game_mode);
            println!("PLAYER ADDRESS: {:?}", player_one.address);
            println!("PLAYER CAR: {:?}", player_one.car);
            println!("PLAYER SCORE: {:?}", player_one.score);
            println!("PLAYER ENERGY: {:?}", player_one.energy);
            println!("PLAYER SHIELD: {:?}", player_one.shield);
            println!("PLAYER 1 CIPHERS:");
            println!(
                "  CIPHER 1: {:?} - {:?}",
                player_one.get_cipher_1.cipher_type,
                player_one.get_cipher_1.cipher_value
            );
            println!(
                "  CIPHER 2: {:?} - {:?}",
                player_one.get_cipher_2.cipher_type,
                player_one.get_cipher_2.cipher_value
            );
            println!(
                "  CIPHER 3: {:?} - {:?}",
                player_one.get_cipher_3.cipher_type,
                player_one.get_cipher_3.cipher_value
            );
            // println!("PLAYER 2 CIPHERS:");
        // println!("  CIPHER 1: {:?} - {:?}", player_two.get_cipher_1.cipher_type,
        // player_two.get_cipher_1.cipher_value);
        // println!("  CIPHER 2: {:?} - {:?}", player_two.get_cipher_2.cipher_type,
        // player_two.get_cipher_2.cipher_value);
        // println!("  CIPHER 3: {:?} - {:?}", player_two.get_cipher_3.cipher_type,
        // player_two.get_cipher_3.cipher_value);
        }

        fn get_ciphers(ref world: IWorldDispatcher) {
            // let START_ENERGY = 6;
            let REGEN_SECONDS: u64 = 3;
            let caller_address = get_caller_address();
            let mut player = get!(world, caller_address, (GamePlayer));

            let current_time = get_block_timestamp();
            let time_since_action: u64 = current_time - player.last_action_timestamp;

            let energy_regenerated: u64 = time_since_action / REGEN_SECONDS;
            let reminder_seconds: u64 = time_since_action % REGEN_SECONDS;

            println!(
                "Energy regenerated {:?} in {:?} seconds", energy_regenerated, time_since_action
            );
            println!(
                "Current energy: {:?} ({:?} + {:?})",
                player.energy + energy_regenerated.into(),
                player.energy,
                energy_regenerated
            );

            player
                .energy =
                    if (player.energy + energy_regenerated.into() > 10) {
                        10
                    } else {
                        player.energy + energy_regenerated.into()
                    };

            if (player.energy >= 4) {
                // Pseudo-random seed generation using caller address, block_number, game_id, and
                // current time
                let seed = utils::hash4(
                    caller_address.into(),
                    get_block_number().into(),
                    player.game_id.into(),
                    current_time.into()
                );
                // println!("Creating seed with: {:?} / {:?} / {:?} / {:?}", owner,
                // get_block_number(), game_id, current_time);

                // Generate 6 pseudo-random numbers using different hash inputs
                let type_1_hash: u256 = utils::hash2(seed, 1).into();
                let type_2_hash: u256 = utils::hash2(seed, 2).into();
                let type_3_hash: u256 = utils::hash2(seed, 3).into();
                let value_1_hash: u256 = utils::hash2(seed, 4).into();
                let value_2_hash: u256 = utils::hash2(seed, 5).into();
                let value_3_hash: u256 = utils::hash2(seed, 6).into();

                player.get_cipher_1 = GameTrait::gen_cipher(type_1_hash, value_1_hash);
                player.get_cipher_2 = GameTrait::gen_cipher(type_2_hash, value_2_hash);
                player.get_cipher_3 = GameTrait::gen_cipher(type_3_hash, value_3_hash);

                player.energy -= 4;
                player.last_action_timestamp = current_time - reminder_seconds;

                set!(world, (player));
            }
        }

        fn set_player(
            ref world: IWorldDispatcher, ciphers: Array<Cipher>, player_address: ContractAddress
        ) {
            if ciphers.len() < 2 {
                println!("NO SE HACE NADA");
                return;
            }
    
            let mut player = get!(world, player_address, (GamePlayer));
            let game = get!(world, player.game_id, (Game));
            let mut opponent = if (game.player_1 == player_address) {
                get!(world, game.player_2, (GamePlayer))
            } else {
                get!(world, game.player_1, (GamePlayer))
            };

            let mut cipher_total_value = 0;
            let mut cipher_total_type = CipherTypes::Unknown(());
            // Check for max combo
            if (ciphers.len() == 3
                && ciphers[0].cipher_type == ciphers[1].cipher_type
                && ciphers[0].cipher_type == ciphers[2].cipher_type) {
                cipher_total_value += (*ciphers[0].cipher_value + *ciphers[1].cipher_value + *ciphers[2].cipher_value) * 2;
                cipher_total_type = *ciphers[0].cipher_type;
            }

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
            
            println!(
                "CIPHER 1 TYPE: {:?} VALUE: {:?}", ciphers[0].cipher_type, ciphers[0].cipher_value
            );
            println!(
                "CIPHER 2 TYPE: {:?} VALUE: {:?}", ciphers[1].cipher_type, ciphers[1].cipher_value
            );
            if ciphers.len() == 3 {
                println!(
                    "CIPHER 3 TYPE: {:?} VALUE: {:?}",
                    ciphers[2].cipher_type,
                    ciphers[2].cipher_value
                );
            }
            println!("CIPHER TOTAL TYPE: {:?} VALUE: {:?}", cipher_total_type, cipher_total_value);

            match cipher_total_type {
                CipherTypes::Advance => { 
                    player.score += cipher_total_value.into();
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
                _ => { assert(cipher_total_type == CipherTypes::Unknown, Errors::UNKNOWN_CIPHER_TYPE); },
            }

            // Reset player ciphers
            player.get_cipher_1 = Cipher { cipher_type: CipherTypes::Unknown, cipher_value: 0 };
            player.get_cipher_2 = Cipher { cipher_type: CipherTypes::Unknown, cipher_value: 0 };
            player.get_cipher_3 = Cipher { cipher_type: CipherTypes::Unknown, cipher_value: 0 };

            set!(world, (player));
        }

        fn end_game(
            ref world: IWorldDispatcher, game_id: felt252
        ) { // TODO: Finish logic, assign wins and loses to corresponding account
        // let game_id: usize = game_id.try_into().unwrap();
        // let game = get!(world, game_id, (Game));

        // let player_1 = get!(world, game.player_1, (GamePlayer));
        // let _player_2 = get!(world, game.player_2, (GamePlayer));

        // game.game_status = GameStatus::Ended;

        // player_1.game_id = 0;
        // player_2.game_id = 0;
        }
    }
}
