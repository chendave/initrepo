language: c

arch:
  - amd64
  - arm64

compiler:
  - gcc

install: skip

script:
  - cd csource 
  - make all
