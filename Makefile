IMAGE_NAME:="egor045/munin"
IMAGE_VERSION:=`cat ./version.txt`

container: Dockerfile
	@echo "Building container"
	docker build -t "${IMAGE_NAME}:${IMAGE_VERSION}" .

latest: container
	@echo "Tagging ${IMAGE_NAME}:${IMAGE_VERSION} as latest"
	docker build -t "${IMAGE_NAME}:latest" .

untagged: container
	@echo "Building untagged image ${IMAGE_NAME}"
	docker build -t "${IMAGE_NAME}" .
	
release: container
	@echo "Pushing container ${IMAGE_NAME}:${IMAGE_VERSION}"
	docker push "${IMAGE_NAME}:${IMAGE_VERSION}"
	@echo "Pushing latest"
	docker push "${IMAGE_NAME}:latest"
	@echo "Pushing untagged image ${IMAGE_NAME}"
	docker push "${IMAGE_NAME}"
