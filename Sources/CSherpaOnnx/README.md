`c-api.h` is sherpa-onnx's C API header from tag v2.0.1 (Apache License 2.0,
https://github.com/k2-fsa/sherpa-onnx). The matching prebuilt universal dylibs are fetched by
`scripts/fetch_local_ai_libs.sh` into `Vendor/sherpa-onnx/lib` and embedded in the app by `build.sh`.
This build of sherpa-onnx has no espeak-ng (GPL) inside: Paper Tree turns words into phonemes itself
(see KokoroVoice.swift).
