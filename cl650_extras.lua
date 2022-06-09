local nan = 0/0

function m2ft(m)
	return m * 3.2808399
end

function ft2m(ft)
	return ft / 3.2808399
end

function define_shared_dataref2(Name, Dataref, Type)
	define_shared_dataref(Dataref, Type)
	dataref(Name, Dataref, "writable")
end

function bind_dataref_array(Name, Dataref, Access, Length)
	local i
	for i = 1, Length do 
		dataref(Name .. "_" .. i-1, Dataref .. "[" .. i-1 .. "]", Access)
	end
end

function reassemble_dataref_array(Name, Length)
	local i
	local out = {}
	for i = 1, Length do 
		out[i] = _G[Name .. "_" .. i-1]
	end
	return out
end

function ppairs_iter(t, i)
	local v1 = t[i+1]
	local v2 = t[i+2]
	if v1 ~= nil then
		return i+2, v1, v2
	end
end
function ppairs(t)
	return ppairs_iter, t, 0
end
function cond(...)
	for _, a1, a2 in ppairs{...} do
		if a2 == nil then
			-- "else" branch
			return a1
		elseif a1 then
			-- matched branch
			return a2
		--else continue
		end
	end
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
	-- default weather datarefs
	dataref("cl650_tat", "sim/weather/temperature_le_c", "readonly")
	dataref("cl650_sat", "sim/weather/temperature_ambient_c", "readonly")
	dataref("cl650_rain", "sim/weather/rain_percent", "readonly")
	dataref("cl650_precip_on_acft", "sim/weather/precipitation_on_aircraft_ratio", "readonly")
	dataref("cl650_runway_friction", "sim/weather/runway_friction", "readonly")
	-- CL650 atmospheric model datarefs
	-- WARNING: not actually used for icing simulation!
	dataref("cl650_atmos_sat", "CL650/atmos/Ts", "readonly")
	dataref("cl650_atmos_tat", "CL650/atmos/Tt", "readonly")
	dataref("cl650_atmos_dewpoint", "CL650/atmos/T_dp", "readonly")
	dataref("cl650_atmos_humidity", "CL650/atmos/rh", "readonly")
	-- derived from sim/weather/precipitation_on_aircraft_ratio -- no point in using it
	--datatef("cl650_atmos_m_w_spec", "CL650/atmos/m_w_spec", "readonly")

	-- fml
	dataref("cl650_lfe", "CL650/overhead/press/sel/A", "readonly")
	dataref("cl650_alt_msl", "sim/flightmodel/position/elevation", "readonly")
	bind_dataref_array("cl650_cloud_base_msl", "sim/weather/cloud_base_msl_m", "readonly", 3)
	bind_dataref_array("cl650_cloud_tops_msl", "sim/weather/cloud_tops_msl_m", "readonly", 3)
	bind_dataref_array("cl650_cloud_coverage", "sim/weather/cloud_coverage", "readonly", 3)

	dataref("cl650_wai", "CL650/overhead/ice/wing/mode", "readonly")
	dataref("cl650_cai_L", "CL650/overhead/ice/cowl/L", "readonly")
	dataref("cl650_cai_R", "CL650/overhead/ice/cowl/R", "readonly")
	define_shared_dataref2("cl650_anti_ice_all_ok_taxi_out", "CL650/fo_state/extra/all_anti_ice_ok_taxi_out", "Int")
	define_shared_dataref2("cl650_anti_ice_all_ok_takeoff", "CL650/fo_state/extra/all_anti_ice_ok_takeoff", "Int")
	define_shared_dataref2("cl650_anti_ice_all_ok_landing", "CL650/fo_state/extra/all_anti_ice_ok_landing", "Int")
	define_shared_dataref2("cl650_anti_ice_cowl_ok_taxi_in", "CL650/fo_state/extra/cowl_anti_ice_ok_taxi_in", "Int")
	define_shared_dataref2("cl650_anti_ice_wing_off", "CL650/fo_state/extra/wing_anti_ice_off", "Int")
	define_shared_dataref2("cl650_anti_ice_off", "CL650/fo_state/extra/all_anti_ice_off", "Int")

	dataref("cl650_sim_time", "sim/time/total_flight_time_sec", "readonly")
	dataref("cl650_cai_L_lamp", "CL650/lamps/overhead/anti_ice/cowl/left", "readonly")
	dataref("cl650_cai_R_lamp", "CL650/lamps/overhead/anti_ice/cowl/right", "readonly")
	define_shared_dataref2("cl650_cai_check", "CL650/fo_state/extra/cai_check", "Int")
	cl650_cai = Tracker:new()

	dataref("cl650_wai_L_lamp", "CL650/lamps/overhead/anti_ice/lheat", "readonly")
	dataref("cl650_wai_R_lamp", "CL650/lamps/overhead/anti_ice/rheat", "readonly")
	define_shared_dataref2("cl650_wai_check_off", "CL650/fo_state/extra/wai_check_off", "Int")

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

function cl650_test_off(...)
	return cl650_test_ex(
		function(arg) return arg == 0 end,
		function(arg) return arg ~= 0 end,
		...
	)
end

function cl650_datarefs_update()
	--
	-- environment conditions
	--

	local icing_impossible = ((cl650_tat > 10) and (cl650_sat > 10))
	local icing_temp_onground_cowl = (cl650_sat <= 10)
	local icing_temp_onground_wing = (cl650_sat <= 5)
	local icing_temp_inflight = ((cl650_tat <= 10) and not (cl650_sat <= -40))
	local precipitation = false
	local in_clouds = false
	local clouds_below_400agl = false
	local visible_moisture = false
	local runways_contaminated = false

	-- "Icing conditions exist <...> in the presence of any precipitation"
	if cl650_rain > 0 or cl650_precip_on_acft > 0 then
		precipitation = true
	end
	-- "Mist forms when the relative humidity is greater than about 70%"
	-- "Fog forms when the difference between air temperature and dew point is less than 2.5 °C"
	if cl650_atmos_humidity > 0.70 or math.abs(cl650_atmos_sat - cl650_atmos_dewpoint) < 2.5 then
		visible_moisture = true
	end
	-- Runway friction is not "good" => runway is contaminated
	if cl650_runway_friction > 0 then
		runways_contaminated = true
	end
	-- Whether we are in clouds or have low clouds
	local cl650_cloud_base_msl = reassemble_dataref_array("cl650_cloud_base_msl", 3)
	local cl650_cloud_tops_msl = reassemble_dataref_array("cl650_cloud_tops_msl", 3)
	local cl650_cloud_coverage = reassemble_dataref_array("cl650_cloud_coverage", 3)
	for i, base in ipairs(cl650_cloud_base_msl) do
		local coverage = cl650_cloud_coverage[i]
		local top = cl650_cloud_tops_msl[i]
		if coverage > 0 then
			if base < cl650_alt_msl and cl650_alt_msl < top then
				in_clouds = true
			end
			if cl650_on_ground ~= 0 and m2ft(base - cl650_alt_msl) < 400 or m2ft(top - cl650_alt_msl) < 400 then
				clouds_below_400agl = true
			end
			if cl650_on_ground == 0 and m2ft(base) - cl650_lfe < 400 or m2ft(top) - cl650_lfe < 400 then
				clouds_below_400agl = true
			end
		end
	end
	-- TODO: parse default X-Plane visibility/fog/mist or find a way to determine rh

	--
	-- aircraft state
	--

	local cai_on = cl650_cai_L ~= 0 and cl650_cai_R ~= 0 and cl650_cai_L_lamp ~= 0 and cl650_cai_R_lamp ~= 0
	local cai_off = cl650_cai_L == 0 and cl650_cai_R == 0 and cl650_cai_L_lamp == 0 and cl650_cai_R_lamp == 0
	local wai_on = cl650_wai ~= 0 and cl650_wai_L_lamp ~= 0 and cl650_wai_R_lamp ~= 0
	local wai_off = cl650_wai == 0 and cl650_wai_L_lamp == 0 and cl650_wai_R_lamp == 0

	--
	-- F/O check logic
	--

	--[[
	The wing anti-ice system must be selected and confirmed ON for take-off, when the OAT
	is 5°C (41°F) or below and:
	• visible moisture in any form (such as clouds, fog or mist) is present below 400 feet AGL, or
	• the runway is wet or contaminated, or
	• in the presence of any precipitation (such as rain, snow, sleet or ice crystals).
	If wing anti-ice is selected ON for take-off, the cowl anti-ice must also be selected ON
	--]]
	local icing_cond_onground_wing = (
		icing_temp_onground_wing 
		and (precipitation or visible_moisture or in_clouds or clouds_below_400agl or runways_contaminated)
	)

	--[[
	The engine cowl anti-ice system must be on when the OAT is 10°C (50°F) or below and
	visible moisture in any form is present (such as fog with visibility of one mile or less, rain,
	snow, sleet and ice crystals).
	The engine cowl anti-ice system must also be on when the OAT is 10°C (50°F) or below
	when operating on runways, ramps, or taxiways where surface snow, ice, standing water
	or slush is present.
	--]]
	local icing_cond_onground_cowl = (
		icing_temp_onground_cowl
		and (precipitation or visible_moisture or in_clouds or clouds_below_400agl or runways_contaminated)
	)

	--[[
	Icing conditions exist in flight at a TAT of 10°C (50°F) or below and
	visible moisture in any form is encountered (such as clouds, rain, snow,
	sleet or ice crystals), except when the SAT is –40°C (–40°F) or below.
	The [cowl/wing] anti-ice system must be on:
	At or above 22,000 feet:
	• when ice is indicated by the ice detection system, or
	• when in icing conditions, if an ice detector has failed.
	Below 22,000 feet:
	• when in icing conditions, or
	• when ice is indicated by the ice detection system.
	--]]
	local icing_cond_inflight = (
		icing_temp_inflight
		and (precipitation or visible_moisture or in_clouds)
	)

	if cl650_on_ground ~= 0 then
		-- on the ground, populate datarefs for taxi and takeoff checklists
		cl650_anti_ice_all_ok_taxi_out = (
			-- require WING A/ICE = OFF
			wai_off
			and cond(
				-- if icing impossible, require COWL A/ICE = OFF
				icing_impossible, cai_off,
				-- if in icing conditions, require COWL A/ICE = ON
				icing_cond_onground_cowl, cai_on,
				-- otherwise, accept any consistent state
				cai_off or cai_on
			)
		) and 1 or 0
		cl650_anti_ice_all_ok_takeoff = (
			cond (
				-- if icing impossible, require WING A/ICE = OFF
				icing_impossible, wai_off,
				-- if in icing conditions, require WING A/ICE = ON
				icing_cond_onground_wing, wai_on,
				-- otherwise, accept any consistent state
				wai_off or wai_on
			)
			and cond(
				-- if wing anti-ice is selected ON, the cowl anti-ice must also be selected ON
				wai_on, cai_on,
				-- if icing impossible, require COWL A/ICE = OFF
				icing_impossible, cai_off,
				-- if in icing conditions, require COWL A/ICE = ON
				icing_cond_onground_cowl, cai_on,
				-- otherwise, accept any consistent state
				cai_off or cai_on
			)
		) and 1 or 0
		cl650_anti_ice_cowl_ok_taxi_in = (
			cond(
				-- if icing impossible, require COWL A/ICE = OFF
				icing_impossible, cai_off,
				-- if in icing conditions, require COWL A/ICE = ON
				icing_cond_onground_cowl, cai_on,
				-- otherwise, accept any consistent state
				cai_off or cai_on
			)
		) and 1 or 0
		cl650_anti_ice_all_ok_landing = 0

	elseif cl650_alt_msl < ft2m(22000) then
		-- in air below 22000 ft, populate datarefs for landing checklists
		cl650_anti_ice_all_ok_landing = (
			cond(
				-- if icing impossible, require WING A/ICE = OFF
				icing_impossible, wai_off,
				-- if in icing conditions, require WING A/ICE = ON
				icing_inflight, wai_on,
				-- otherwise, accept any consistent state
				wai_off or wai_on
			)
			and cond(
				-- if wing anti-ice is selected ON, the cowl anti-ice must also be selected ON
				wai_on, cai_on,
				-- if icing impossible, require COWL A/ICE = OFF
				icing_impossible, cai_off,
				-- if in icing conditions (or will be in icing conditions on ground), require COWL A/ICE = ON
				icing_inflight or icing_onground_cowl, cai_on,
				-- otherwise, accept any consistent state
				cai_off or cai_on
			)
		) and 1 or 0
		cl650_anti_ice_all_ok_taxi_out = 0
		cl650_anti_ice_all_ok_takeoff = 0
		cl650_anti_ice_cowl_ok_taxi_in = 0

	else
		-- above 22000 ft, disregard (no anti-ice items in checklists in the cruise phase)
		cl650_anti_ice_all_ok_landing = 0
		cl650_anti_ice_all_ok_taxi_out = 0
		cl650_anti_ice_all_ok_takeoff = 0
		cl650_anti_ice_cowl_ok_taxi_in = 0
	end

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
