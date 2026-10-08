FROM scratch

ARG APPS_REFERENCE_REV=f8fd5830c2c228560ccb94b3d0fa009ac53fb128
LABEL org.opencontainers.image.title="Neat YOLO26 C++ container POC" \
      org.opencontainers.image.description="Thin cross-compiled C++ app image using the Modalix target runtime" \
      org.opencontainers.image.source="https://github.com/sima-neat/apps" \
      org.opencontainers.image.revision="${APPS_REFERENCE_REV}"

COPY build/cmake/yolo26-benchmark /app/yolo26-benchmark

ENTRYPOINT ["/app/yolo26-benchmark"]
