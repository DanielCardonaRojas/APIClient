docs:
	jazzy -c \
		--module APIClient \
		--swift-build-tool spm \
		--build-tool-arguments -Xswiftc,-swift-version,-Xswiftc,5
