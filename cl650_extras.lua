local nan = 0/0

function define_shared_dataref2(Name, Dataref, Type)
	define_shared_dataref(Dataref, Type)
	dataref(Name, Dataref, "writable")
end

Tracker = {}
function Tracker:new()
	o = {
		last_state = nil,
		last_edge = nan,
	}
	setmetatable(o, self)
	self.__index = self
	return o
end

function Tracker:push(timestamp, state)
	if self.last_state ~= nil then
		-- detect any edge, aka "(not self.last_state and state) or (self.last_state and not state)"
		if not not self.last_state ~= not not state then
			self.last_edge = timestamp
		end
	end
	self.last_state = state
end

if PLANE_ICAO == 'CL60' then

--
-- BEGIN plugin configuration
-- TODO: expose as settings and/or autodetect based on CL650 version (for workarounds)
--
local cl650_use_steep_app = true
local cl650_use_cabin_lts = true
local cl650_use_datarefs = true
--
-- END plugin configuration
--

--
-- BEGIN state
--
if cl650_use_steep_app then
	local cl650_steep_app_state = 0
	dataref("cl650_steep_app_value", "CL650/pedestal/taws/steep_app_value", "writable")
end

if cl650_use_cabin_lts then
	local cl650_lts_overhead_cabin_last = -1
	local cl650_lts_cabin_downwash_state = -1
	local cl650_lts_cabin_upwash_fwd_state = -1
	local cl650_lts_cabin_upwash_aft_state = -1
	local cl650_lts_initialized = false
	-- CL650/overhead/int_lts/cabin_value: 1 == NORM, 0 == ON
	dataref("cl650_lts_overhead_cabin", "CL650/overhead/int_lts/cabin_value", "readonly")
	dataref("cl650_lts_cabin_downwash", "CL650/cabin_lts/downwash_value", "writable")
	dataref("cl650_lts_cabin_upwash_fwd", "CL650/cabin_lts/upwash_fwd_value", "writable")
	dataref("cl650_lts_cabin_upwash_aft", "CL650/cabin_lts/upwash_aft_value", "writable")
end

if cl650_use_datarefs then
	dataref("cl650_on_ground", "sim/flightmodel/failures/onground_all", "readonly")
	dataref("cl650_tat", "sim/weather/temperature_le_c", "readonly")
	dataref("cl650_sat", "sim/weather/temperature_ambient_c", "readonly")
	dataref("cl650_wai", "CL650/overhead/ice/wing/mode", "readonly")
	dataref("cl650_cai_L", "CL650/overhead/ice/cowl/L", "readonly")
	dataref("cl650_cai_R", "CL650/overhead/ice/cowl/R", "readonly")
	define_shared_dataref2("cl650_anti_ice_cowl_ok", "CL650/fo_state/extra/cowl_anti_ice_ok", "Int")
	define_shared_dataref2("cl650_anti_ice_cowl_ok_or_off", "CL650/fo_state/extra/cowl_anti_ice_ok_or_off", "Int")
	define_shared_dataref2("cl650_anti_ice_all_ok_or_on", "CL650/fo_state/extra/all_anti_ice_ok_or_on", "Int")
	define_shared_dataref2("cl650_anti_ice_all_ok_or_cowl_on", "CL650/fo_state/extra/all_anti_ice_ok_or_cowl_on", "Int")
	define_shared_dataref2("cl650_anti_ice_wing_ok", "CL650/fo_state/extra/wing_anti_ice_ok", "Int")
	define_shared_dataref2("cl650_anti_ice_all_ok", "CL650/fo_state/extra/all_anti_ice_ok", "Int")
	define_shared_dataref2("cl650_anti_ice_wing_off", "CL650/fo_state/extra/wing_anti_ice_off", "Int")
	define_shared_dataref2("cl650_anti_ice_off", "CL650/fo_state/extra/all_anti_ice_off", "Int")

	dataref("cl650_sim_time", "sim/time/total_flight_time_sec", "readonly")
	dataref("cl650_cai_L_lamp", "CL650/lamps/overhead/anti_ice/cowl/left", "readonly")
	dataref("cl650_cai_R_lamp", "CL650/lamps/overhead/anti_ice/cowl/right", "readonly")
	define_shared_dataref2("cl650_cai_check", "CL650/fo_state/extra/cai_check", "Int")
	cl650_cai = Tracker:new()

	dataref("cl650_wai_L_lamp", "CL650/lamps/overhead/anti_ice/lheat", "readonly")
	dataref("cl650_wai_R_lamp", "CL650/lamps/overhead/anti_ice/rheat", "readonly")

	dataref("cl650_apu_pwr_fuel", "CL650/overhead/apu/pwr_fuel", "readonly")
	dataref("cl650_apu_start_stop", "CL650/overhead/apu/start_stop", "readonly")
	dataref("cl650_apu_avail", "CL650/lamps/overhead/apu/start_stop/avail", "readonly")
	dataref("cl650_apu_start", "CL650/lamps/overhead/apu/start_stop/start", "readonly")
	define_shared_dataref2("cl650_apu_start_or_avail", "CL650/fo_state/extra/apu_start_or_avail", "Int")
	define_shared_dataref2("cl650_apu_off", "CL650/fo_state/extra/apu_off", "Int")

	dataref("cl650_probe_L", "CL650/overhead/ice/probe/L", "readonly")
	dataref("cl650_probe_R", "CL650/overhead/ice/probe/R", "readonly")
	define_shared_dataref2("cl650_probe_heat", "CL650/fo_state/extra/probe_heat", "Int")

	dataref("cl650_wind_L", "CL650/overhead/ice/wind/L", "readonly")
	dataref("cl650_wind_R", "CL650/overhead/ice/wind/R", "readonly")
	define_shared_dataref2("cl650_windshield_heat", "CL650/fo_state/extra/windshield_heat", "Int")

	dataref("cl650_thr_rev_arm_L", "CL650/pedestal/thr_rev/arm_L", "readonly")
	dataref("cl650_thr_rev_arm_R", "CL650/pedestal/thr_rev/arm_R", "readonly")
	define_shared_dataref2("cl650_thr_rev_arm", "CL650/fo_state/extra/thr_rev_arm", "Int")

	dataref("cl650_thr_rev_L", "CL650/pedestal/throttle/reverse_L", "readonly")
	dataref("cl650_thr_rev_R", "CL650/pedestal/throttle/reverse_R", "readonly")
	define_shared_dataref2("cl650_thr_rev", "CL650/fo_state/extra/thr_rev", "Int")

	dataref("cl650_sgwais_test", "CL650/SGWAIS/test", "readonly")
	dataref("cl650_sgwais_test_on", "CL650/lamps/SGWAIS/test/on", "readonly")
	dataref("cl650_sgwais_fail_hi", "CL650/lamps/SGWAIS/temp/fail_hi", "readonly")
	dataref("cl650_sgwais_fail_lo", "CL650/lamps/SGWAIS/temp/fail_lo", "readonly")
	define_shared_dataref2("cl650_sgwais_ok", "CL650/fo_state/extra/SGWAIS_ok", "Int")

	dataref("cl650_10th_L_closed", "CL650/lamps/overhead/bleed/10st/left/closed", "readonly")
	dataref("cl650_10th_isol", "CL650/lamps/overhead/bleed/10st/isol", "readonly")
	dataref("cl650_10th_apu_lcv", "CL650/lamps/overhead/bleed/10st/apu_lcv/open", "readonly")
	dataref("cl650_10th_R_closed", "CL650/lamps/overhead/bleed/10st/right/closed", "readonly")
	define_shared_dataref2("cl650_apu_bleed", "CL650/fo_state/extra/apu_bleed", "Int")

	-- CL650/overhead/signs/*: -1 == ON, 0 == OFF, 1 == AUTO
	dataref("cl650_signs_no_smoking", "CL650/overhead/signs/no_smoking", "readonly")
	dataref("cl650_signs_seatbelt", "CL650/overhead/signs/seatbelt", "readonly")
	define_shared_dataref2("cl650_pax_signs", "CL650/fo_state/extra/pax_signs", "Int")

end
--
-- END state
--

--
-- CL650 WA: TAWS steep approach switch
--

function cl650_steep_app_update()
	cl650_steep_app_value = cl650_steep_app_state
end

function cl650_steep_app_set(arg)
	cl650_steep_app_state = arg
	cl650_steep_app_update()
end

if cl650_use_steep_app then
	add_macro("CL650: SB 650−34−008 TAWS steep approach", "cl650_steep_app_set(1)", "cl650_steep_app_set(0)")
	cl650_steep_app_update()
	do_sometimes("cl650_steep_app_update()")
end

--
-- CL650 WA: cabin lights switch
--

function cl650_cabin_lts_update()
	if cl650_lts_overhead_cabin == 0 then
		if cl650_lts_overhead_cabin_last == 1 then
			-- remember 
			cl650_lts_initialized = true
			cl650_lts_cabin_downwash_state = cl650_lts_cabin_downwash
			cl650_lts_cabin_upwash_fwd_state = cl650_lts_cabin_upwash_fwd
			cl650_lts_cabin_upwash_aft_state = cl650_lts_cabin_upwash_aft
		end
	
		-- continuously override
		cl650_lts_cabin_downwash = 1
		cl650_lts_cabin_upwash_fwd = 1
		cl650_lts_cabin_upwash_aft = 1
	else
		if cl650_lts_overhead_cabin_last == 0 then
			if not cl650_lts_initialized then
				-- FIXME: load from config
				cl650_lts_initialized = true
				cl650_lts_cabin_downwash_state = 1
				cl650_lts_cabin_upwash_fwd_state = 1
				cl650_lts_cabin_upwash_aft_state = 1
			end

			-- restore
			cl650_lts_cabin_downwash = cl650_lts_cabin_downwash_state
			cl650_lts_cabin_upwash_aft = cl650_lts_cabin_upwash_aft_state
			cl650_lts_cabin_upwash_fwd = cl650_lts_cabin_upwash_fwd_state
		end
	end
		
	cl650_lts_overhead_cabin_last = cl650_lts_overhead_cabin
end

if cl650_use_cabin_lts then
	do_often("cl650_cabin_lts_update()")
end

--
-- CL650 WA: extra datarefs for auto-FO
--

function cl650_test_ex(on, off, ...)
	if select('#', ...) < 1 then
		return -1
	end

	local all_true = true
	local all_false = true
	for i, v in ipairs({...}) do
		if on(v) then all_false = false
		elseif off(v) then all_true = false
		else return -1
		end
	end

	if all_true then return 1
	elseif all_false then return 0
	else return -1
	end
end

function cl650_test(...)
	return cl650_test_ex(
		function(arg) return arg ~= 0 end,
		function(arg) return arg == 0 end,
		...
	)
end

function cl650_datarefs_update()
	local wai_ok = false
	local cai_ok = false

	local cai_on = cl650_cai_L ~= 0 and cl650_cai_R ~= 0 and cl650_cai_L_lamp ~= 0 and cl650_cai_R_lamp ~= 0
	local cai_off = cl650_cai_L == 0 and cl650_cai_R == 0 and cl650_cai_L_lamp == 0 and cl650_cai_R_lamp == 0
	local wai_on = cl650_wai ~= 0 and cl650_wai_L_lamp ~= 0 and cl650_wai_R_lamp ~= 0
	local wai_off = cl650_wai == 0 and cl650_wai_L_lamp == 0 and cl650_wai_R_lamp == 0

	local in_icing_conditions = ((cl650_tat <= 10) and not (cl650_sat <= -40))
	if not in_icing_conditions then
		-- icing cannot occur, require all a/ice OFF
		wai_ok = wai_off
		cai_ok = cai_off
	else
		-- icing can occur in some conditions, require manual attention
		-- FIXME: implement correct logic (require proper anti-ice configuration for given OAT and humidity)
	end

	cl650_anti_ice_wing_ok = wai_ok and 1 or 0
	cl650_anti_ice_cowl_ok = cai_ok and 1 or 0
	cl650_anti_ice_all_ok = (wai_ok and cai_ok) and 1 or 0

	cl650_anti_ice_cowl_ok_or_off = (cai_ok or cai_off) and 1 or 0
	cl650_anti_ice_all_ok_or_on = ((wai_ok or wai_on) and (cai_ok or cai_on)) and 1 or 0
	cl650_anti_ice_all_ok_or_cowl_on = ((wai_ok or wai_off) and (cai_ok or cai_on)) and 1 or 0
	cl650_anti_ice_wing_off = wai_off and 1 or 0
	cl650_anti_ice_off = (wai_off and cai_off) and 1 or 0

	-- "only after 45 seconds from selecting the COWL switch/lights on, can the cowl anti-ice system be confirmed operational"
	cl650_cai:push(cl650_sim_time, cai_on)
	cai_reliable = cl650_cai.last_state and cl650_sim_time - cl650_cai.last_edge > 45

	-- "COWL A/ICE ON" CAS message is equivalent to COWL L+R lights
	cl650_cai_check = (
		cai_reliable
		and cl650_cai_L_lamp ~= 0
		and cl650_cai_R_lamp ~= 0
	) and 1 or 0

	-- CL650/fo_state/extra/probe_heat == CL650/overhead/ice/probe/L && CL650/overhead/ice/probe/R
	cl650_probe_heat = cl650_test(cl650_probe_L, cl650_probe_R)

	-- CL650/fo_state/extra/windshield_heat == CL650/overhead/ice/wind/L && CL650/overhead/ice/wind/R
	cl650_windshield_heat = cl650_test(cl650_wind_L, cl650_wind_R)

	-- CL650/fo_state/extra/thr_rev_arm == CL650/pedestal/thr_rev/arm_L && CL650/pedestal/thr_rev/arm_R
	cl650_thr_rev_arm = cl650_test(cl650_thr_rev_arm_L, cl650_thr_rev_arm_R)

	-- CL650/fo_state/extra/thr_rev == CL650/pedestal/throttle/reverse_L && CL650/pedestal/throttle/reverse_R
	cl650_thr_rev = cl650_test(cl650_thr_rev_L, cl650_thr_rev_R)

	-- CL650/fo_state/extra/apu_bleed
	cl650_apu_bleed = cl650_test(
		cl650_10th_L_closed,
		cl650_10th_apu_lcv,
		cl650_10th_isol,
		cl650_10th_R_closed
	)

	-- CL650/fo_state/extra/pax_signs
	cl650_pax_signs = cl650_test_ex(
		function(arg) return arg == -1 end,
		function(arg) return arg == 0 end,
		cl650_signs_no_smoking,
		cl650_signs_seatbelt
	)

	-- CL650/fo_state/extra/apu_start_or_avail
	cl650_apu_start_or_avail = (
		cl650_apu_pwr_fuel > 0
		and cl650_apu_start_stop > 0
		and (cl650_apu_avail > 0 or cl650_apu_start > 0)
	) and 1 or 0

	-- CL650/fo_state/extra/apu_off
	cl650_apu_off = (
		cl650_apu_start_stop == 0
		and cl650_apu_avail == 0
		and cl650_apu_start == 0
	) and 1 or 0

	-- CL650/fo_state/extra/SGWAIS_ok
	cl650_sgwais_ok = (
		cl650_sgwais_test == 0
		and cl650_sgwais_test_on == 0
		and cl650_sgwais_fail_lo == 0
		and cl650_sgwais_fail_hi == 0
	) and 1 or 0

end

if cl650_use_datarefs then
	do_often("cl650_datarefs_update()")
end

end -- PLANE_ICAO == 'CL60'
