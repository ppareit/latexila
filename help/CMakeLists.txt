include ("${latexila_SOURCE_DIR}/cmake/itstool.cmake")

itstool (
	"documentation" # target name
	"${latexila_SOURCE_DIR}/help" # src dir
	"${latexila_BINARY_DIR}/help" # tmp dir
	"${CMAKE_INSTALL_PREFIX}/share/gnome/help/latexila" # install dir
)
