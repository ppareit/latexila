# The purpose of this function is to use the right binary "valac-X.Y" directly.
# For distributions like Gentoo which permits to install several Vala versions
# in parallel, it's a lot easier for the packaging.
#
# 'version_required' must have the pattern "X.Y". For example "0.12", but not
# "0.12.1".
#
# If a minimum version is required, for example the "0.12.1", then it must be
# checked outside this function, with the VALA_VERSION variable:
#
#	if ((NOT VALA_FOUND) OR
#	    ("${VALA_VERSION}" VERSION_LESS "0.12.1"))
#		message (FATAL_ERROR "valac-0.12 >= 0.12.1 required")
#	endif ()
#
# VALA_FOUND is always set.
# If VALA_FOUND is true, then VALA_EXECUTABLE and VALA_VERSION are also set.
#
# TODO:
# To be more generic, the function should accept several versions, for example
# "0.12" and "0.14".  It will first search the 0.14 version, and then the 0.12
# if the 0.14 is not found.

function (find_vala version_required)

	# Search for the valac executable in the usual system paths
	find_program (_vala_executable "valac-${version_required}")

	if (_vala_executable)
		# HACK: be able to use the variable where the function is called.
		# It would be better to do something cleaner, for instance return the value...
		set (VALA_EXECUTABLE ${_vala_executable} PARENT_SCOPE)
		mark_as_advanced (VALA_EXECUTABLE)

		set (VALA_FOUND true PARENT_SCOPE)
		mark_as_advanced (VALA_FOUND)

		# Determine the valac version
		execute_process (COMMAND ${_vala_executable} --version
			OUTPUT_VARIABLE _vala_version)
		string (REGEX MATCH "[.0-9]+" _vala_version "${_vala_version}")

		set (VALA_VERSION ${_vala_version} PARENT_SCOPE)
		mark_as_advanced (VALA_VERSION)

		message (STATUS "Found Vala: ${_vala_executable} (found version \"${_vala_version}\")")
	else ()
		set (VALA_FOUND false PARENT_SCOPE)
		mark_as_advanced (VALA_FOUND)

		message (STATUS "Vala ${version_required} not found")
	endif ()
endfunction ()
