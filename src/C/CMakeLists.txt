file (GLOB sources *.c *.h)
add_executable (latexila ${sources})
install (TARGETS latexila DESTINATION "bin")
