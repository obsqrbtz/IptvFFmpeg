# Build and run

## 1. Build FFmpeg

```bash
cd FFmpeg
./configure --prefix=$(pwd)/build
make
make install
```

## 2. Build app

```bash
swift build
```

## 3. Run

```bash
.build/debug/IptvFFmpeg
```