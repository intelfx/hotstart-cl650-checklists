local nan = 0/0

function round(arg, places)
	if places and places > 0 then
		local m = 10^places
		return math.floor(arg * m + 0.5) / m
	elseif places and places < 0 then
		local m = 10^(-places)
		return math.floor(arg / m + 0.5) * m
	else
		return math.floor(arg + 0.5)
	end
end

function round_up_to(arg, scale)
	return math.floor((arg + scale - 1) / scale) * scale
end

function round_down_to(arg, scale)
	return math.floor(arg / scale) * scale
end

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
	define_shared_dataref2("cl650_version", "CL650/version_guess", "Int")
	cl650_version = 105
	if XPLMFindDataRef("CL650/atmos/Ts") and XPLMFindDataRef("abus/CL650/modules/ICE_DET/0/wires/ICE") then
		cl650_version = 106
	end

	dataref("cl650_on_ground", "sim/flightmodel/failures/onground_all", "readonly")
	-- default weather datarefs
	dataref("cl650_tat", "sim/weather/temperature_le_c", "readonly")
	dataref("cl650_sat", "sim/weather/temperature_ambient_c", "readonly")
	dataref("cl650_rain", "sim/weather/rain_percent", "readonly")
	dataref("cl650_precip_on_acft", "sim/weather/precipitation_on_aircraft_ratio", "readonly")
	dataref("cl650_runway_friction", "sim/weather/runway_friction", "readonly")
	-- CL650 atmospheric model datarefs
	-- WARNING: not actually used for icing simulation!
	if cl650_version >= 106 then
		dataref("cl650_atmos_sat", "CL650/atmos/Ts", "readonly")
		dataref("cl650_atmos_tat", "CL650/atmos/Tt", "readonly")
		dataref("cl650_atmos_dewpoint", "CL650/atmos/T_dp", "readonly")
		dataref("cl650_atmos_humidity", "CL650/atmos/rh", "readonly")
		-- derived from sim/weather/precipitation_on_aircraft_ratio -- no point in using it
		--datatef("cl650_atmos_m_w_spec", "CL650/atmos/m_w_spec", "readonly")
	else
		cl650_atmos_sat = nan
		cl650_atmos_tat = nan
		cl650_atmos_dewpoint = nan
		cl650_atmos_humidity = 0
	end

	-- fml
	dataref("cl650_lfe", "CL650/overhead/press/sel/A", "readonly")
	dataref("cl650_alt_msl", "sim/flightmodel/position/elevation", "readonly")
	bind_dataref_array("cl650_cloud_base_msl", "sim/weather/cloud_base_msl_m", "readonly", 3)
	bind_dataref_array("cl650_cloud_tops_msl", "sim/weather/cloud_tops_msl_m", "readonly", 3)
	bind_dataref_array("cl650_cloud_coverage", "sim/weather/cloud_coverage", "readonly", 3)

	if cl650_version >= 106 then
		dataref("cl650_ice_det_L", "abus/CL650/modules/ICE_DET/0/wires/ICE", "readonly")
		dataref("cl650_ice_det_L_fail", "abus/CL650/modules/ICE_DET/0/wires/FAIL", "readonly")
		dataref("cl650_ice_det_R", "abus/CL650/modules/ICE_DET/1/wires/ICE", "readonly")
		dataref("cl650_ice_det_R_fail", "abus/CL650/modules/ICE_DET/1/wires/FAIL", "readonly")
	else
		cl650_ice_det_L = 0
		cl650_ice_det_L_fail = 1
		cl650_ice_det_R = 0
		cl650_ice_det_R_fail = 1
	end

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
	dataref("cl650_10th_apu_lcv_sw", "CL650/overhead/bleed/10st/apu_lcv", "readonly")
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

	local cai_sw_on = cl650_cai_L ~= 0 and cl650_cai_R ~= 0
	local cai_on = cl650_cai_L ~= 0 and cl650_cai_R ~= 0 and cl650_cai_L_lamp ~= 0 and cl650_cai_R_lamp ~= 0
	local cai_off = cl650_cai_L == 0 and cl650_cai_R == 0 and cl650_cai_L_lamp == 0 and cl650_cai_R_lamp == 0
	local wai_on = cl650_wai ~= 0 and cl650_wai_L_lamp ~= 0 and cl650_wai_R_lamp ~= 0
	local wai_off = cl650_wai == 0 and cl650_wai_L_lamp == 0 and cl650_wai_R_lamp == 0

	local ice_det = cl650_ice_det_L ~= 0 or cl650_ice_det_R ~= 0
	local ice_det_fail = cl650_ice_det_L_fail ~= 0 or cl650_ice_det_R_fail ~= 0

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
		ice_det
		or (
			(ice_det_fail or cl650_alt_msl < ft2m(22000))
			and icing_temp_inflight
			and (precipitation or visible_moisture or in_clouds)
		)
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
				icing_cond_inflight, wai_on,
				-- otherwise, accept any consistent state
				wai_off or wai_on
			)
			and cond(
				-- if wing anti-ice is selected ON, the cowl anti-ice must also be selected ON
				wai_on, cai_on,
				-- if icing impossible, require COWL A/ICE = OFF
				icing_impossible, cai_off,
				-- if in icing conditions (or will be in icing conditions on ground), require COWL A/ICE = ON
				icing_cond_inflight or icing_cond_onground_cowl, cai_on,
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
	cl650_cai:push(cl650_sim_time, cai_sw_on)
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
		cl650_10th_apu_lcv_sw,
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


---
--- GUI
---

--[[
local cl650_tab_preselected = nil

function cl650_is_tab_preselected(idx)
	if idx == cl650_gui_tab_preselect then
		return imgui.constant.TabItemFlags.SetSelected
	else
		return imgui.constant.TabItemFlags.None
	end
end
--]]

--
-- WARNING, SHITCODE BELOW
-- Okay, this needs to be killed with fire at the first opportunity.
-- But, it'll work for now, I've got an FNO to attend.
--

local MassUnits = {
	NONE = 0,
	LBS = 1,
	KG = 2,
}
function MassUnits.valid(units)
	if units == MassUnits.LBS or units == MassUnits.KG then
		return true
	end
	return false
end
function MassUnits.convert(value, old, new)
	if old == new then
		return value
	elseif old == MassUnits.LBS and new == MassUnits.KG then
		return round(value * 0.45359237)
	elseif old == MassUnits.KG and new == MassUnits.LBS then
		return round(value * 2.2046226)
	end
	error("MassUnits.convert: unsupported units")
end
function MassUnits.text(units)
	if units == MassUnits.LBS then
		return "lbs"
	elseif units == MassUnits.KG then
		return "kg"
	end
end

local FuelMass = {}
function FuelMass:new()
	o = {
		text = "",
		value = nil,
		units = MassUnits.NONE,
		parsed = false,
	}
	setmetatable(o, self)
	self.__index = self
	return o
end
function FuelMass:update_text(changed, text, buddy)
	if changed then
		self.text = text

		local parsed = text:lower():gsub(" ", "")
		local v, u = string.match(parsed, "^(%d+)(%a*)$")
		if v ~= nil and u == "lbs" then
			self.parsed = true
			self.value = tonumber(v)
			self.units = MassUnits.LBS
		elseif v ~= nil and u == "kg" then
			self.parsed = true
			self.value = tonumber(v)
			self.units = MassUnits.KG
		elseif v ~= nil and u == "" then
			self.parsed = true
			self.value = tonumber(v)
			if not MassUnits.valid(self.units) then
				if buddy and MassUnits.valid(buddy.units) then
					self.units = buddy.units
				else
					self.units = MassUnits.LBS
				end
			end
		else
			self.parsed = false
		end
	end
end
function FuelMass:update_units(units)
	if self.parsed and MassUnits.valid(self.units) and MassUnits.valid(units) and self.units ~= units then
		self.value = MassUnits.convert(self.value, self.units, units)
		self.text = tostring(self.value) -- maybe append new units string if it was there?
	end
	self.units = units
end
function FuelMass:valid()
	return self.parsed and MassUnits.valid(self.units)
end
function FuelMass:get(units)
	return MassUnits.convert(self.value, self.units, units)
end

local DensityUnits = {
	NONE = 0,
	LBS_PER_GAL = 1,
	KG_PER_L = 2,
}
function DensityUnits.valid(units)
	if units == DensityUnits.LBS_PER_GAL or units == DensityUnits.KG_PER_L then
		return true
	end
	return false
end
function DensityUnits.convert(value, old, new)
	if old == new then
		return value
	elseif old == DensityUnits.LBS_PER_GAL and new == DensityUnits.KG_PER_L then
		return round(value * 0.11982643, 3)
	elseif old == DensityUnits.KG_PER_L and new == DensityUnits.LBS_PER_GAL then
		return round(value * 8.3454045, 3)
	end
	error("DensityUnits.convert: unsupported units")
end
local FuelDensity = {}
function FuelDensity:new()
	o = {
		text = "",
		value = nil,
		units = DensityUnits.NONE,
		parsed = false,
	}
	setmetatable(o, self)
	self.__index = self
	return o
end
function FuelDensity:update_text(changed, text)
	if changed then
		self.text = text

		local parsed = text:lower():gsub(" ", "")
		local v, u = string.match(parsed, "^([%d.]+)([%a/]*)$")
		print("FuelDensity:update_text: changed=true, text=" .. text .. ", parsed=" .. parsed .. ", v=" .. tostring(v) .. ", u=" .. tostring(u))
		if v ~= nil and (u == "lb/g" or u == "lbs/g" or u == "lb/gal" or u == "lbs/gal") then
			self.parsed = true
			self.value = tonumber(v)
			self.units = DensityUnits.LBS_PER_GAL
		elseif v ~= nil and (u == "kg/l" or u == "kgs/l" or u == "kg/liter" or u == "kgs/liter") then
			self.parsed = true
			self.value = tonumber(v)
			self.units = DensityUnits.KG_PER_L
		elseif v ~= nil and u == "" then
			self.parsed = true
			self.value = tonumber(v)
			if not DensityUnits.valid(self.units) then
				if self.value <= 1 then
					self.units = DensityUnits.KG_PER_L
				elseif self.value >= 6 then
					self.units = DensityUnits.LBS_PER_GAL
				end
			end
		else
			self.parsed = false
		end
	end
end
function FuelDensity:update_units(units)
	if self.parsed and DensityUnits.valid(self.units) and DensityUnits.valid(units) and self.units ~= units then
		self.value = DensityUnits.convert(self.value, self.units, units)
		self.text = tostring(self.value) -- maybe append new units string if it was there?
	end
	self.units = units
end
function FuelDensity:valid()
	return self.parsed and DensityUnits.valid(self.units)
end

local cl650_fuel_in = FuelMass:new()
local cl650_fuel_out = FuelMass:new()
local cl650_fuel_density = FuelDensity:new()

function cl650_extras_gui_build_fuel(wnd)
	local wip = "Fuel assistant"

	local text_x, text_y = imgui.CalcTextSize(wip)
        local x1, y1 = imgui.GetCursorScreenPos()
        local x2, y2 = imgui.GetContentRegionMax()

	local text_x1 = (x1 + x2 - text_x) / 2
	local text_y1 = (y1 + y2 - text_y) / 2
	local text_x2 = (x1 + x2 + text_x) / 2
	local text_y2 = (y1 + y2 + text_y) / 2
	imgui.SetCursorPosX((x1 + x2 - text_x) / 2)
	imgui.TextUnformatted(wip)

	local changed, text = imgui.InputTextWithHint("Sensed fuel", "<amount> kg or lbs", cl650_fuel_in.text, 20)
	cl650_fuel_in:update_text(changed, text)
	imgui.SameLine()
	if imgui.RadioButton("lbs##in", cl650_fuel_in.units == MassUnits.LBS) then
		cl650_fuel_in:update_units(MassUnits.LBS)
	end
	imgui.SameLine()
	if imgui.RadioButton("kg##in", cl650_fuel_in.units == MassUnits.KG) then
		cl650_fuel_in:update_units(MassUnits.KG)
	end

	local changed, text = imgui.InputTextWithHint("Desired fuel", "<amount> kg or lbs", cl650_fuel_out.text, 20)
	cl650_fuel_out:update_text(changed, text)
	imgui.SameLine()
	if imgui.RadioButton("lbs##out", cl650_fuel_out.units == MassUnits.LBS) then
		cl650_fuel_out:update_units(MassUnits.LBS)
	end
	imgui.SameLine()
	if imgui.RadioButton("kg##out", cl650_fuel_out.units == MassUnits.KG) then
		cl650_fuel_out:update_units(MassUnits.KG)
	end

	local changed, text = imgui.InputTextWithHint("Fuel density", "<amount> lbs/gal or kg/l", cl650_fuel_density.text, 20)
	cl650_fuel_density:update_text(changed, text)
	imgui.SameLine()
	if imgui.RadioButton("lbs/gal", cl650_fuel_density.units == DensityUnits.LBS_PER_GAL) then
		cl650_fuel_density:update_units(DensityUnits.LBS_PER_GAL)
	end
	imgui.SameLine()
	if imgui.RadioButton("kg/l", cl650_fuel_density.units == DensityUnits.KG_PER_L) then
		cl650_fuel_density:update_units(DensityUnits.KG_PER_L)
	end

	imgui.Separator()

	if not (cl650_fuel_in:valid() and cl650_fuel_out:valid() and cl650_fuel_density:valid()) then
		return
	end

	if cl650_fuel_out.value <= cl650_fuel_in.value then
		imgui.TextUnformatted("No fuel needed")
		return
	end

	local mass_units, volume_units_str, volume_scale
	if cl650_fuel_density.units == DensityUnits.LBS_PER_GAL then
		mass_units = MassUnits.LBS
		volume_units_str = "gal"
		volume_scale = 10
	elseif cl650_fuel_density.units == DensityUnits.KG_PER_L then
		mass_units = MassUnits.KG
		volume_units_str = "liter"
		volume_scale = 40
	else
		return
	end

	local request_mass = cl650_fuel_out:get(mass_units) - cl650_fuel_in:get(mass_units)
	local request_volume = round_up_to(request_mass / cl650_fuel_density.value, volume_scale)

	local fms_mass = cl650_fuel_in:get(cl650_fuel_in.units) + MassUnits.convert(request_volume * cl650_fuel_density.value, mass_units, cl650_fuel_out.units)
	local fms_mass_units_str = MassUnits.text(cl650_fuel_out.units)

	imgui.TextUnformatted("Request:   " .. tostring(request_volume) .. " " .. volume_units_str)
	imgui.TextUnformatted("FMS total: " .. tostring(round_down_to(fms_mass, 10)) .. " " .. fms_mass_units_str)
end

--
-- SHITCODE END
-- Okay, maybe not. Anyway, below is just regular shitcode.
--

function cl650_extras_gui_build_stub(wnd)
	local wip = "WORK IN PROGRESS"

	local color_fg = imgui.GetColorU32(imgui.constant.Col.Text)
	local color_bg = imgui.GetColorU32(imgui.constant.Col.WindowBg)
	local text_x, text_y = imgui.CalcTextSize(wip)
        local x1, y1 = imgui.GetCursorScreenPos()
        local x2, y2 = imgui.GetContentRegionMax()
	imgui.DrawList_AddLine(x1, y1, x2, y2, color_fg, 1.5)
	imgui.DrawList_AddLine(x2, y1, x1, y2, color_fg, 1.5)

	local text_x1 = (x1 + x2 - text_x) / 2
	local text_y1 = (y1 + y2 - text_y) / 2
	local text_x2 = (x1 + x2 + text_x) / 2
	local text_y2 = (y1 + y2 + text_y) / 2
	imgui.DrawList_AddRectFilled(text_x1-1, text_y1-1, text_x2+1, text_y2+1, color_bg)
	imgui.DrawList_AddText(text_x1, text_y1, color_fg, wip)
end

function cl650_extras_gui_build(wnd, x, y)
	if imgui.BeginTabBar("MainTabBar") then
		-- Thank you, f**ing FlyWithLua bag-of-dicks!
		-- TODO: patch OPTIONAL_BOOL_ARG in FWL's ImGui bindings to accept nils, then revisit
		--if imgui.BeginTabItem("Fuel", nil, cl650_is_tab_preselected(1))
		if imgui.BeginTabItem("Fuel") then
			cl650_extras_gui_build_fuel(wnd)
			imgui.EndTabItem()
		end
		if imgui.BeginTabItem("[REDACTED]") then
			cl650_extras_gui_build_stub(wnd)
			imgui.EndTabItem()
		end
		if imgui.BeginTabItem("Preferences") then
			cl650_extras_gui_build_stub(wnd)
			imgui.EndTabItem()
		end
		imgui.EndTabBar()
		--cl650_tab_preselected = nil
	end
end

--
-- GUI scaffolding
--


local cl650_gui_state = false
local cl650_gui_is_fuel = false
local cl650_gui_last_fuel_phase = -1
local cl650_gui = nil

function cl650_extras_gui_create()
	if cl650_gui_state then
		return
	end
	assert(cl650_gui == nil, "CL650_extras: cl650_gui_state is false, but cl650_gui is not nil")

	cl650_gui_state = true
	cl650_gui_is_fuel = false

	local function float_wnd_create2(x, y, ...)
		local w = float_wnd_create(x, y, ...)
		float_wnd_set_resizing_limits(w, x, y, x, y)
		return w
	end
	cl650_gui = float_wnd_create2(700, 490, 1, true)

	-- Center the window.
	-- Seems easy enough? Fuck you, not scaling-aware.
	--float_wnd_set_position(cl650_gui, (SCREEN_WIDTH - x) / 2, (SCREEN_HIGHT - y) / 2)
	-- Nothing is ever easy.
	local g_left, g_top, g_right, g_bottom = XPLMGetScreenBoundsGlobal()
	local left, top, right, bottom = float_wnd_get_geometry(cl650_gui)
	float_wnd_set_geometry(cl650_gui,
		(g_left+g_right)/2 - (right-left)/2, (g_top+g_bottom)/2 - (bottom-top)/2,
		(g_left+g_right)/2 + (right-left)/2, (g_top+g_bottom)/2 + (bottom-top)/2
	)

	float_wnd_set_title(cl650_gui, "CL650 extras")
	float_wnd_set_imgui_builder(cl650_gui, "cl650_extras_gui_build")
	float_wnd_set_onclose(cl650_gui, "cl650_extras_gui_destroy")
end

function cl650_extras_gui_destroy()
	if not cl650_gui_state then
		return
	end
	assert(cl650_gui ~= nil, "CL650_extras: cl650_gui_state is true, but cl650_gui is nil")

	float_wnd_destroy(cl650_gui)
	cl650_gui = nil
	cl650_gui_state = false
	cl650_gui_is_fuel = nil
end

function cl650_extras_gui_show(arg)
	if arg and not cl650_gui_state then
		cl650_extras_gui_create()
	elseif not arg and cl650_gui_state then
		cl650_extras_gui_destroy()
	end
end

function cl650_extras_gui_toggle()
	cl650_extras_gui_show(not cl650_gui_state)
end

function cl650_extras_gui_create_fuel()
	if cl650_gui_state then
		return
	end
	assert(cl650_gui == nil, "CL650_extras: cl650_gui_state is false, but cl650_gui is not nil")

	cl650_gui_state = true
	cl650_gui_is_fuel = true

	local function float_wnd_create2(x, y, ...)
		local w = float_wnd_create(x, y, ...)
		float_wnd_set_resizing_limits(w, x, y, x, y)
		return w
	end
	cl650_gui = float_wnd_create2(956, 140, 2, true)
	float_wnd_set_position(cl650_gui, 50, 230)
	float_wnd_set_title(cl650_gui, "CL650 extras: fuel assistant")
	float_wnd_set_imgui_builder(cl650_gui, "cl650_extras_gui_build_fuel")
	float_wnd_set_onclose(cl650_gui, "cl650_extras_gui_destroy_fuel")
end

function cl650_extras_gui_destroy_fuel()
	if not cl650_gui_is_fuel then
		return
	end
	cl650_extras_gui_destroy()
end

function cl650_extras_gui_fuel()
	if cl650_fbo_fuel_phase == 4 and cl650_gui_last_fuel_phase ~= 4 then
		cl650_extras_gui_create_fuel()
	end
	if cl650_fbo_fuel_phase ~= 4 and cl650_gui_last_fuel_phase == 4 then
		-- this sounds very heavy-handed for something that's called every second
		-- but cl650_extras_gui_destroy_fuel() short-circuits very early if fuel assistant is not active
		cl650_extras_gui_destroy_fuel()
	end
	cl650_gui_last_fuel_phase = cl650_fbo_fuel_phase
end

add_macro("CL650: extras", "cl650_extras_gui_show(true)", "cl650_extras_gui_show(false)", "deactivate")
create_command("FlyWithLua/CL650/toggle_gui", "Open/close CL650 extras GUI", "cl650_extras_gui_toggle()", "", "")
-- XXX: debugging
--cl650_extras_gui_show(true)

dataref("cl650_fbo_fuel_phase", "CL650/fbo/refuel/phase", "readonly")
do_often("cl650_extras_gui_fuel()")

end -- PLANE_ICAO == 'CL60'
