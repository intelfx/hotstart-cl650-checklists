xpilot_present = XPLMFindDataRef('xpilot/version')
pe_present = XPLMFindDataRef('pilotedge/status/connected')
cl60_present = PLANE_ICAO == 'CL60'

function ptt_begin()
	if cl60_present then
		command_begin('CL650/contwheel/0/ptt_up')
	end
	if xpilot_present then
		command_begin('xpilot/ptt')
	end
	if pe_present then
		command_begin('sim/operation/contact_atc')
	end
end

function ptt_end()
	if cl60_present then
		command_end('CL650/contwheel/0/ptt_up')
	end
	if xpilot_present then
		command_end('xpilot/ptt')
	end
	if pe_present then
		command_end('sim/operation/contact_atc')
	end
end

create_command("FlyWithLua/ptt/ptt_0", "Captain's control wheel PTT switch to RT (incl online networks)", "ptt_begin()", "", "ptt_end()")