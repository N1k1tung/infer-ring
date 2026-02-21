# Infer Ring

Infer Ring enables local LLM inference by combining the memory of multiple iOS and macOS devices. 
Just run the app on each device - they will find each other automatically, and combine their RAM to unlock models that wouldn’t fit on a single machine. 
It can work over Wi-Fi and wired connections - meaning you can just stick a USB cable, including between 2 phones or tablets, and they will connect automatically preferring wired connections.

You can download the app from the App Store: [link](https://apps.apple.com/app/infer-ring/id6757767558) both for mac and iOS.

It supports both tensor and pipeline parallelism, defaulting to the latter - mainly because of the connection means. Wi-Fi and pre-TB5 over RDMA connections will result in sharp performance decline.

## Performance

In general you can expect slightly faster batched prefill (prompt processing) and slightly slower token generation (due to the need to transfer data between devices).

Running on MBP with M1 Pro and iPhone 17 Pro:

| Model               | MBP (M1 Pro) TG | MBP (M1 Pro) PP | Mac + iPhone TG (-12%) | Mac + iPhone PP (+11%) |
| ------------------- | --------------- | --------------- | ---------------------- | ---------------------- |
| GLM4.7 Flash 4-bit  | 38              | 170             | 33                     | 190                    |
| Qwen3-30B-A3B 4-bit | 42              | 200             | 37                     | 225                    |


## Notes

- Using USB3.2 compatible cable is recommended for the best performance.
- Running on iOS/macOS 26.2 or later will utilize neural acceleration kernels on compatible devices.

## Acknowledgments

The app is built on top of [MLX](https://github.com/mlx-explore/mlx-swift-lm).

The idea and the initial implementation of sharding was inspired by [Exo](https://github.com/exo-explore/exo).