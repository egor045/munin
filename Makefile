IMAGE_NAME:="egor045/munin"
IMAGE_VERSION:=`cat ./version.txt`

container: Dockerfile
	@echo "Building container"
	docker build -t "${IMAGE_NAME}:${IMAGE_VERSION}" .

latest: container
	@echo "Tagging ${IMAGE_NAME}:${IMAGE_VERSION} as latest"
	docker tag ${IMAGE_NAME}:${IMAGE_VERSION} ${IMAGE_NAME}:latest

release: container
	@echo "Pushing container ${IMAGE_NAME}:${IMAGE_VERSION}"
	docker push "${IMAGE_NAME}:${IMAGE_VERSION}"
	@echo "Pushing latest"
	docker push "${IMAGE_NAME}:latest"
