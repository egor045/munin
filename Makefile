IMAGE_NAME:="egor045/munin-test"
IMAGE_VERSION:=`cat ./version.txt`

container: Dockerfile
	@echo "Building container"
	docker build -t "${IMAGE_NAME}:${IMAGE_VERSION}" .

release: container
	@echo "Pushing container"
	docker push "${IMAGE_NAME}:${IMAGE_VERSION}"
