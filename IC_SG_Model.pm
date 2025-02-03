dtmc

// game_match Parameters
const int total_sessions = 40;
const int session_duration = 30; // seconds

// Probability to generate balls
const double p_generate_go = .7;
const double p_generate_no_go = 1-p_generate_go;

// Change difficulty bounds
const double decrease_bound = 0.7;
const double increase_bound = 0.8;

// Game parameters
const int max_balls_in_game = 4 + 1; // 4 on table + 1 for gameover
const int max_no_go_wrong_throws = 3;

const int ticks_to_generate_easy = 5;
const int ticks_to_generate_normal = 4;
const int ticks_to_generate_hard = 3;

const int max_throwable_balls_session = floor(session_duration / ticks_to_generate_hard);

formula total_balls_in_game = 
    (in_game_go_balls_counter + in_game_no_go_balls_counter);

formula total_balls_generated_session = total_balls_in_game + correct_throws_counter + wrong_throws_counter;

formula session_is_over = 
    // removing one because it is the one generated when session begins
    ((((max(total_balls_generated_session-1,0)) * dm_active_ticks_to_generate_ball) + 
        (dm_active_ticks_to_generate_ball-sg_timer_to_spawn))
        = session_duration);

// calculate difficulty modifier
formula correct_throws_score = 
    (correct_throws_counter / max(correct_throws_counter + wrong_throws_counter, 1));
formula table_free_score = few_balls_on_table_timer / session_duration;

formula player_score = (correct_throws_score + table_free_score) / 2;
formula decrease_difficulty = 
    (player_score < decrease_bound);
formula stay_difficulty = 
    (decrease_bound <= player_score & player_score <= increase_bound);
formula increase_difficulty = 
    (player_score > increase_bound);

formula is_easy_difficulty_active = 
    (dm_active_ticks_to_generate_ball = ticks_to_generate_easy);
formula is_normal_difficulty_active = 
    (dm_active_ticks_to_generate_ball = ticks_to_generate_normal);
formula is_hard_difficulty_active = 
    (dm_active_ticks_to_generate_ball = ticks_to_generate_hard);

module Manager
    // starting difficulty
    dm_active_ticks_to_generate_ball: [ticks_to_generate_hard .. ticks_to_generate_easy] init ticks_to_generate_easy;
    dm_current_session: [0..total_sessions] init 0;
    dm_have_to_prepare_new_session: bool init false;
    dm_running_session: bool init false;
    dm_game_match_is_over: bool init false;
    
    [StartGameMatch]
        (dm_running_session=false) &
        (dm_have_to_prepare_new_session=false) & 
        (dm_game_match_is_over=false)
        -> 
        (dm_current_session'=0) &
        (dm_active_ticks_to_generate_ball'= ticks_to_generate_easy)
    ;

    [StartNewSession]
        (dm_running_session=false) &
        (dm_game_match_is_over=false) &
        (dm_have_to_prepare_new_session=false) & 
        (dm_current_session<total_sessions)
        ->
        (dm_running_session'=true)
    ;

    [EndSession]
        (dm_running_session=true) &
        (dm_have_to_prepare_new_session=false) & 
        (dm_game_match_is_over=false)
        ->
        (dm_have_to_prepare_new_session'=true) &
        (dm_running_session'=false)
    ;

    [EndGameMatchGameplay]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            ((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            ((patient_recovery_timer>=0) & 
            (total_balls_in_game>=0)) &
            (sg_timer_to_spawn>=0) & 
            (patient_recovery_timer>=0)
        -> 
        (dm_running_session'=false) &
        (dm_game_match_is_over'=true)
    ;

    [EndGameMatchPatient]
        !(dm_game_match_is_over) &   
        (dm_running_session) &
        !(dm_have_to_prepare_new_session) &
        !(session_is_over) & 
        !((total_balls_in_game = max_balls_in_game) |
        (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
        (patient_premature_end_game_match) & 
        (throw_made_type=0) &
        ((patient_recovery_timer=0) & 
        (total_balls_in_game>=0)) &
        (sg_timer_to_spawn>=0) & 
        (patient_recovery_timer>=0)
        -> 
        (dm_running_session'=false) &
        (dm_game_match_is_over'=true)
    ;

    [EndGameMatchManager]
        (dm_running_session=false) &
        (dm_have_to_prepare_new_session=false) & 
        (dm_game_match_is_over=false) &
        (dm_current_session=total_sessions)
        -> 
        (dm_game_match_is_over'=true)
    ;

    []  // Study Ended
        (dm_game_match_is_over)
        -> 
            true
    ;

    [] // Difficulty Management EASY STAY
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_easy_difficulty_active) & 
            (decrease_difficulty | stay_difficulty)
        ->
            // define new session parameters 
            // -- No need for stay

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;
    
    [] // Difficulty Management EASY INCREASE
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_easy_difficulty_active) & 
            (increase_difficulty)
        ->
            // define new session parameters 
            (dm_active_ticks_to_generate_ball'=ticks_to_generate_normal) &

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;

    [] // Difficulty Management NORMAL DECREASE
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_normal_difficulty_active) & 
            (decrease_difficulty)
        ->
            // define new session parameters 
            (dm_active_ticks_to_generate_ball'=ticks_to_generate_easy) &

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;

    [] // Difficulty Management NORMAL STAY
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_normal_difficulty_active) & 
            (stay_difficulty)
        ->
            // define new session parameters 
            // -- No need for stay

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;

    [] // Difficulty Management NORMAL INCREASE
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_normal_difficulty_active) & 
            (increase_difficulty)
        ->
            // define new session parameters 
            (dm_active_ticks_to_generate_ball'=ticks_to_generate_hard) &

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;
    
    [] // Difficulty Management HARD DECREASE
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_hard_difficulty_active) & 
            (decrease_difficulty)
        ->
            // define new session parameters 
            (dm_active_ticks_to_generate_ball'=ticks_to_generate_normal) &

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;

    [] // Difficulty Management HARD STAY
            (dm_have_to_prepare_new_session=true) &
            (dm_running_session=false) & 
            (dm_game_match_is_over=false) &
            (dm_current_session<total_sessions) &
            (is_hard_difficulty_active) & 
            (increase_difficulty | stay_difficulty)
        ->
            // define new session parameters 
            // -- No need for stay

            (dm_have_to_prepare_new_session'=false) &
            (dm_current_session'=dm_current_session+1)
    ;
endmodule

formula p_increase_few_balls_timer = ((total_balls_in_game < 3) ? 1.0 : 0.0);
formula p_not_increase_few_balls_timer = (1 - p_increase_few_balls_timer);

module Gameplay
    sg_timer_to_spawn : [0..ticks_to_generate_easy] init 0;
    few_balls_on_table_timer : [0..session_duration] init 0;
    in_game_go_balls_counter : [0..max_balls_in_game] init 0;
    in_game_no_go_balls_counter : [0..max_balls_in_game] init 0;
    
    [StartGameMatch]
            (dm_running_session=false) &
            (dm_game_match_is_over=false)
        ->
            true
    ;

    [StartNewSession]
            (dm_running_session=false) &
            (dm_game_match_is_over=false)
        ->
            (sg_timer_to_spawn'=0) &
            (few_balls_on_table_timer'=0) &
            (in_game_go_balls_counter'=0) &
            (in_game_no_go_balls_counter'=0)
    ;

    [EndSession]
            (dm_running_session=true) &
            (session_is_over) &
            (dm_game_match_is_over=false)
        ->
            true
    ;

    [EndGameMatchGameplay]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            ((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            ((patient_recovery_timer>=0) & 
            (total_balls_in_game>=0)) &
            (sg_timer_to_spawn>=0) & 
            (patient_recovery_timer>=0)
        -> 
            true
    ;

    [EndGameMatchPatient]
        !(dm_game_match_is_over) &   
        (dm_running_session) &
        !(dm_have_to_prepare_new_session) &
        !(session_is_over) & 
        !((total_balls_in_game = max_balls_in_game) |
        (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
        (patient_premature_end_game_match) & 
        (throw_made_type=0) &
        ((patient_recovery_timer=0) & 
        (total_balls_in_game>=0)) &
        (sg_timer_to_spawn>=0) & 
        (patient_recovery_timer>=0)
        -> 
            true
    ;

    [EndGameMatchManager]
            (dm_running_session=false) &
            (dm_game_match_is_over=false)
        ->
            true
    ;

    []  // Study Ended
            (dm_game_match_is_over)
        -> 
            true
        ;

    [] // Generate Ball 
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            !((patient_recovery_timer=0) & 
            (total_balls_in_game>0)) &
            (sg_timer_to_spawn=0) & 
            (patient_recovery_timer>=0) &
            (in_game_go_balls_counter < max_balls_in_game) &
            (in_game_no_go_balls_counter < max_balls_in_game) &
            ((in_game_go_balls_counter + in_game_no_go_balls_counter) < max_balls_in_game)
        -> 
        p_generate_go:
            (in_game_go_balls_counter'= in_game_go_balls_counter+1) &
            (sg_timer_to_spawn'=dm_active_ticks_to_generate_ball)
        +
        p_generate_no_go:
            (in_game_no_go_balls_counter'= in_game_no_go_balls_counter+1) & 
            (sg_timer_to_spawn'=dm_active_ticks_to_generate_ball)
        ;

    [UpdateTimers] // Increase timer to spawn balls
            !(dm_game_match_is_over) &
            (dm_running_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            !((patient_recovery_timer=0) & (total_balls_in_game>0)) &
            (sg_timer_to_spawn>0) & 
            (patient_recovery_timer>0) &
            (few_balls_on_table_timer<session_duration)
        -> 
            p_increase_few_balls_timer :
                (sg_timer_to_spawn'=sg_timer_to_spawn-1) &
                (few_balls_on_table_timer'=few_balls_on_table_timer+1)
            +
            p_not_increase_few_balls_timer :
                (sg_timer_to_spawn'=sg_timer_to_spawn-1)
        ;
        
    [] // Increase timer to spawn balls
            !(dm_game_match_is_over) &
            (dm_running_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            !((patient_recovery_timer=0) & (total_balls_in_game>0)) &
            (sg_timer_to_spawn>0) & 
            (patient_recovery_timer=0) &
            (few_balls_on_table_timer<session_duration)
        -> 
            p_increase_few_balls_timer :
                (sg_timer_to_spawn'=sg_timer_to_spawn-1) &
                (few_balls_on_table_timer'=few_balls_on_table_timer+1)
            +
            p_not_increase_few_balls_timer :
                // true
                // This can not happen because it would mean that 
                // there are balls on the table and the patient does not throw them
                (sg_timer_to_spawn'=sg_timer_to_spawn-1)
        ;

    [ThrowGoBall]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
              (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) &
            ((patient_recovery_timer=0) & 
             (in_game_go_balls_counter > 0)) &
            (sg_timer_to_spawn>=0) &
            (throw_made_type=1 | throw_made_type=2) &
            (in_game_go_balls_counter > 0)
        ->
            (in_game_go_balls_counter'=in_game_go_balls_counter-1)
        ;
        
    [ThrowNoGoBall]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
              (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) &
            ((patient_recovery_timer=0) & 
             (in_game_no_go_balls_counter > 0)) &
            (sg_timer_to_spawn>=0) &
            (throw_made_type=3 | throw_made_type=4) &
            (correct_throws_counter < max_throwable_balls_session) &
            (wrong_throws_counter < max_throwable_balls_session) &
            (no_go_wrong_throws_counter < max_throwable_balls_session)
        ->
            (in_game_no_go_balls_counter'=in_game_no_go_balls_counter-1)
        ;
endmodule

// Probability to throw balls
formula p_throw_go_ball = (in_game_go_balls_counter / max(total_balls_in_game,1));
formula p_throw_no_go_ball = 1 - p_throw_go_ball;

// Healthy
// formula p_throw_correct_go = .9657142857;
// formula p_throw_correct_no_go = .8357142857;
// formula p_throw_wrong_go = 1 - p_throw_correct_go;
// formula p_throw_wrong_no_go = 1 - p_throw_correct_no_go;

// formula p_fast_recovery = .5828571429;
// formula p_normal_recovery = .3257142857;
// formula p_slow_recovery = .0757142857;
// formula p_stop_game_match = .0157142857;

// Mild NCD
// formula p_throw_correct_go = .8114285714;
// formula p_throw_correct_no_go = .6428571429;
// formula p_throw_wrong_go = 1 - p_throw_correct_go;
// formula p_throw_wrong_no_go = 1 - p_throw_correct_no_go;

// formula p_fast_recovery = .17142857141;
// formula p_normal_recovery = .6085714286;
// formula p_slow_recovery = .1957142857;
// formula p_stop_game_match = .02428571429;

// Major NCD
formula p_throw_correct_go = .6714285714;
formula p_throw_correct_no_go = .4714285714;
formula p_throw_wrong_go = 1 - p_throw_correct_go;
formula p_throw_wrong_no_go = 1 - p_throw_correct_no_go;

formula p_fast_recovery = .0;
formula p_normal_recovery = .3714285714;
formula p_slow_recovery = .5828571429;
formula p_stop_game_match = .0457142857;

const patient_fast_recovery_time = 0;
const patient_medium_recovery_time = 3;
const patient_slow_recovery_time = 6;

formula thrown_go_ball_correct =    throw_made_type=1 ? 1.0 : 0.0;
formula thrown_go_ball_wrong =      throw_made_type=2 ? 1.0 : 0.0;
formula thrown_no_go_ball_correct = throw_made_type=3 ? 1.0 : 0.0;
formula thrown_no_go_ball_wrong =   throw_made_type=4 ? 1.0 : 0.0;

module Patient
    patient_have_to_begin_game_match: bool init true;
    patient_recovery_timer : [0..patient_slow_recovery_time] init 0;
    patient_premature_end_game_match : bool init false;

    correct_throws_counter: [0..max_throwable_balls_session] init 0;
    wrong_throws_counter: [0..max_throwable_balls_session] init 0;
    no_go_wrong_throws_counter: [0..max_throwable_balls_session] init 0;
    
    // 0 none                       ->  (throw_made_type=0)
    // 1 thrown_go_ball_correct     ->  (throw_made_type=1)
    // 2 thrown_go_ball_wrong       ->  (throw_made_type=2)
    // 3 thrown_no_go_ball_correct  ->  (throw_made_type=3)
    // 4 thrown_no_go_ball_wrong    ->  (throw_made_type=4)
    throw_made_type : [0..4] init 0;

    [StartGameMatch]
            (patient_have_to_begin_game_match=true) & 
            (dm_running_session=false) &
            (dm_game_match_is_over=false)
        -> 
            (patient_have_to_begin_game_match'=false)
    ;

    [StartNewSession]
            (patient_have_to_begin_game_match=false) & 
            (dm_running_session=false) &
            (dm_game_match_is_over=false)
        ->
            (patient_recovery_timer'=0) &
            (throw_made_type'=0) &
            (correct_throws_counter'=0) &
            (wrong_throws_counter'=0) &
            (no_go_wrong_throws_counter'=0)
    ;

    [EndSession]
            (patient_have_to_begin_game_match=false) & 
            (dm_running_session=true) &
            (dm_game_match_is_over=false)
        ->
            true
    ;

    [EndGameMatchGameplay]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            ((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            ((patient_recovery_timer>=0) & 
            (total_balls_in_game>=0)) &
            (sg_timer_to_spawn>=0) & 
            (patient_recovery_timer>=0)
        -> 
            true
    ;
    
    [EndGameMatchPatient]
        !(dm_game_match_is_over) &   
        (dm_running_session) &
        !(dm_have_to_prepare_new_session) &
        !(session_is_over) & 
        !((total_balls_in_game = max_balls_in_game) |
        (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
        (patient_premature_end_game_match) & 
        (throw_made_type=0) &
        ((patient_recovery_timer=0) & 
        (total_balls_in_game>=0)) &
        (sg_timer_to_spawn>=0) & 
        (patient_recovery_timer>=0)
        -> 
            true
    ;

    [EndGameMatchManager]
        !(dm_game_match_is_over) &
        (patient_have_to_begin_game_match=false) & 
        (dm_running_session=false)
        -> 
            true
    ;

    []  // Study Ended
            (dm_game_match_is_over)
        -> 
            true
    ;

    [UpdateTimers] // ReadyToThrowTimer
        !(dm_game_match_is_over) &
        (dm_running_session) &
        !(session_is_over) & 
        !((total_balls_in_game = max_balls_in_game) |
        (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
        !(patient_premature_end_game_match) & 
        (throw_made_type=0) &
        !((patient_recovery_timer=0) & (total_balls_in_game>0)) &
        (sg_timer_to_spawn>0) & 
        (patient_recovery_timer>0)
    ->
        (patient_recovery_timer'=patient_recovery_timer-1)
    ;

    [] // DecidingWhatToThrow
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
            (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) & 
            (throw_made_type=0) &
            ((patient_recovery_timer=0) & 
            (total_balls_in_game>0)) &
            (sg_timer_to_spawn>=0)
        ->  
            p_throw_go_ball * p_throw_correct_go:
                (throw_made_type'=1)
            +
            p_throw_go_ball * p_throw_wrong_go:
                (throw_made_type'=2)
            +
            p_throw_no_go_ball * p_throw_correct_no_go:
                (throw_made_type'=3)
            +
            p_throw_no_go_ball * p_throw_wrong_no_go:
                (throw_made_type'=4)
        ;

    [ThrowGoBall]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
              (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) &
            ((patient_recovery_timer=0) & 
             (in_game_go_balls_counter > 0)) &
            (sg_timer_to_spawn>=0) &
            (throw_made_type=1 | throw_made_type=2) &
            (correct_throws_counter < max_throwable_balls_session) &
            (wrong_throws_counter < max_throwable_balls_session)
        ->
            p_fast_recovery * thrown_go_ball_correct: // fast
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_recovery_timer'=patient_fast_recovery_time) &
                (throw_made_type'=0)
            +
            p_fast_recovery * thrown_go_ball_wrong: // fast
                (wrong_throws_counter'=wrong_throws_counter+1) &
                (patient_recovery_timer'=patient_fast_recovery_time) &
                (throw_made_type'=0)
            +
            p_normal_recovery * thrown_go_ball_correct: // medium
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_recovery_timer'=patient_medium_recovery_time) &
                (throw_made_type'=0)
            +
            p_normal_recovery * thrown_go_ball_wrong: // medium
                (wrong_throws_counter'=wrong_throws_counter+1) &
                (patient_recovery_timer'=patient_medium_recovery_time) &
                (throw_made_type'=0)
            +
            p_slow_recovery * thrown_go_ball_correct:// slow
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_recovery_timer'=patient_slow_recovery_time) &
                (throw_made_type'=0)
            +
            p_slow_recovery * thrown_go_ball_wrong: // slow
                (wrong_throws_counter'=wrong_throws_counter+1) &
                (patient_recovery_timer'=patient_slow_recovery_time) &
                (throw_made_type'=0)
            +
            p_stop_game_match: // stop game_match
                (patient_recovery_timer'=patient_fast_recovery_time) &
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_premature_end_game_match'=true)&
                (throw_made_type'=0)
        ;

    [ThrowNoGoBall]
            !(dm_game_match_is_over) &   
            (dm_running_session) &
            !(dm_have_to_prepare_new_session) &
            !(session_is_over) & 
            !((total_balls_in_game = max_balls_in_game) |
              (no_go_wrong_throws_counter > max_no_go_wrong_throws)) &
            !(patient_premature_end_game_match) &
            ((patient_recovery_timer=0) & 
             (in_game_no_go_balls_counter > 0)) &
            (sg_timer_to_spawn>=0) &
            (throw_made_type=3 | throw_made_type=4) &
            (correct_throws_counter < max_throwable_balls_session) &
            (wrong_throws_counter < max_throwable_balls_session) &
            (no_go_wrong_throws_counter < max_throwable_balls_session)
        ->
            p_fast_recovery * thrown_no_go_ball_correct: // fast
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_recovery_timer'=patient_fast_recovery_time) &
                (throw_made_type'=0)
            +
            p_fast_recovery * thrown_no_go_ball_wrong: // fast
                (wrong_throws_counter'=wrong_throws_counter+1) &
                (no_go_wrong_throws_counter'=no_go_wrong_throws_counter+1) &
                (patient_recovery_timer'=patient_fast_recovery_time) &
                (throw_made_type'=0)
            +
            p_normal_recovery * thrown_no_go_ball_correct: // medium
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_recovery_timer'=patient_medium_recovery_time) &
                (throw_made_type'=0)
            +
            p_normal_recovery * thrown_no_go_ball_wrong: // medium
                (wrong_throws_counter'=wrong_throws_counter+1) &
                (no_go_wrong_throws_counter'=no_go_wrong_throws_counter+1) &
                (patient_recovery_timer'=patient_medium_recovery_time) &
                (throw_made_type'=0)
            +
            p_slow_recovery * thrown_no_go_ball_correct: // slow
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_recovery_timer'=patient_slow_recovery_time) &
                (throw_made_type'=0)
            +
            p_slow_recovery * thrown_no_go_ball_wrong: // slow
                (wrong_throws_counter'=wrong_throws_counter+1) &
                (no_go_wrong_throws_counter'=no_go_wrong_throws_counter+1) &
                (patient_recovery_timer'=patient_slow_recovery_time) &
                (throw_made_type'=0)
            +
            p_stop_game_match: // stop game_match
                (patient_recovery_timer'=patient_fast_recovery_time) &
                (correct_throws_counter'=correct_throws_counter+1) &
                (patient_premature_end_game_match'=true) &
                (throw_made_type'=0)
        ;
endmodule

// Difficulty active can be retrievied using 
// EASY: dm_active_ticks_to_generate_ball = 5
// NORMAL: dm_active_ticks_to_generate_ball = 4
// HARD: dm_active_ticks_to_generate_ball = 3

// Usefull formulas for properties
formula game_match_is_over = 
    (((total_balls_in_game = max_balls_in_game) | (no_go_wrong_throws_counter > max_no_go_wrong_throws)) | patient_premature_end_game_match | dm_current_session=total_sessions);
formula active_throwable_balls_session = floor(session_duration / ticks_to_generate_hard);

formula gameover_during_gamematch = 
    (total_balls_in_game = max_balls_in_game) | (no_go_wrong_throws_counter > max_no_go_wrong_throws) | (patient_premature_end_game_match);
formula game_is_running = (dm_running_session) & !(session_is_over) & !(gameover_during_gamematch);
formula patient_can_throw = (throw_made_type=0) & (patient_recovery_timer=0) & (total_balls_in_game>0);

rewards "time"
    !game_match_is_over:  1;
endrewards

rewards "difficultyDecrease"
    (dm_have_to_prepare_new_session=true) & 
    (is_normal_difficulty_active | is_hard_difficulty_active) &
    (decrease_difficulty) : 1; 
endrewards

rewards "runningSession"
    game_is_running:  1;
endrewards

rewards "changed_difficulty"
    (dm_have_to_prepare_new_session=true) : 1;
endrewards

rewards "difficulty_easy_stay"
    (dm_have_to_prepare_new_session=true) & 
    (is_easy_difficulty_active) &
    (decrease_difficulty | stay_difficulty) : 1; 
endrewards

rewards "difficulty_easy_increase"
    (dm_have_to_prepare_new_session=true) & 
    (is_easy_difficulty_active) &
    (increase_difficulty) : 1; 
endrewards

rewards "difficulty_normal_decrease"
    (dm_have_to_prepare_new_session=true) & 
    (is_normal_difficulty_active) &
    (decrease_difficulty) : 1;  
endrewards

rewards "difficulty_normal_stay"
    (dm_have_to_prepare_new_session=true) & 
    (is_normal_difficulty_active) &
    (stay_difficulty) : 1; 
endrewards

rewards "difficulty_normal_increase"
    (dm_have_to_prepare_new_session=true) & 
    (is_normal_difficulty_active) &
    (increase_difficulty) : 1; 
endrewards

rewards "difficulty_hard_decrease"
    (dm_have_to_prepare_new_session=true) & 
    (is_hard_difficulty_active) &
    (decrease_difficulty) : 1; 
endrewards

rewards "difficulty_hard_stay"
    (dm_have_to_prepare_new_session=true) & 
    (is_hard_difficulty_active) &
    (stay_difficulty | increase_difficulty) : 1; 
endrewards

rewards "thrown_go_correct"
    (thrown_go_ball_correct=1):  1;
endrewards

rewards "thrown_go_wrong"
    (thrown_go_ball_wrong=1):  1;
endrewards

rewards "thrown_no_go_correct"
    (thrown_no_go_ball_correct=1):  1;
endrewards

rewards "thrown_no_go_wrong"
    (thrown_no_go_ball_wrong=1):  1;
endrewards