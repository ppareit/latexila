include ("${latexila_SOURCE_DIR}/cmake/itstool.cmake")

itstool (
	"build_tools" # target name
	"${latexila_SOURCE_DIR}/data/build_tools" # src dir
	"${latexila_BINARY_DIR}/data/build_tools" # tmp dir
	"${DATA_DIR}/build_tools" # install dir
)
