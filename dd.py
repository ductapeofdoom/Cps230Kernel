with open("build/payload.com", "rb") as f:
	contents = f.read()
	print(len(contents))
	contents = contents[32:]
	print(len(contents))
	with open("build/payload.com", "wb") as of:
		of.write(contents)