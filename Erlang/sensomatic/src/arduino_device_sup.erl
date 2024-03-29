-module( arduino_device_sup ).
-behaviour( supervisor ).

-export( [ 
	start_link/0, 
	start_worker/1,
	start_or_resume_device/1,
	start_device/1,
	get_devices/0,
	get_device/1
] ).
-export( [ init/1 ] ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Module API
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%==============================================================================
%% start_link/0
%%==============================================================================
start_link() ->
    supervisor:start_link( { local, ?MODULE }, ?MODULE, [] ).

%%==============================================================================
%% start_worker/1
%%==============================================================================
start_worker( Mfa = { Mod, _, _ } ) ->
	start_worker( { Mod, Mfa } );
start_worker( { Id, Mfa = { Mod, _, _ } } ) ->
	ChildSpec = { Id, Mfa, temporary, 1000, supervisor, [ Mod ] },
	supervisor:start_child( ?MODULE, ChildSpec ).

%%==============================================================================
%% start_or_resume_device/1
%%
%% @doc If there is a worker for the device ID, return it's pid, otherwise call
%%      start_device/1
%%==============================================================================
start_or_resume_device( Id ) ->
	case proplists:lookup( Id, sensomatic:devices() ) of
		{ Id, Pid } -> 
			{ resumed, Pid };
		none -> 
			start_device( Id )
	end.

%%==============================================================================
%% start_device/1
%%
%% @doc Start a device process with the given ID
%%==============================================================================
start_device( { Id, PortSpecs } ) ->
	{ ok, Pid } = start_device( Id ),
	lists:foreach( fun( PortSpec ) ->
		arduino_device:add_port( Pid, PortSpec )
	end, PortSpecs ),
	{ ok, Pid };
start_device( Id ) ->
	supervisor:start_child( ?MODULE, {
		Id,
		{ device, start_link, [] },
		permanent,
		1000,
		worker,
		[ device ]
	} ).
	
%%==============================================================================
%% get_devices/0
%%
%% @doc Get all devices as a property list { Id, Pid }
%%==============================================================================
get_devices() ->
	lists:map( fun( { Id, Pid, _, _ } ) ->
		{ Id, Pid }
	end, supervisor:which_children( ?MODULE ) ).

%%==============================================================================
%% get_device/1
%%
%% @doc Get the pid for a device by ID
%%==============================================================================
get_device( Id ) ->
	case proplists:lookup( Id, get_devices() ) of
		{ Id, Pid } -> Pid;
		_ -> throw( unknown_device )
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% supervisor callbacks
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

init( _ ) ->
    { ok, { { one_for_one, 60, 3600 }, [] } }.