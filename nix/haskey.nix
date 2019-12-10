{ mkDerivation, async, base, binary, bytestring, containers
, directory, exceptions, filepath, focus, hashable, haskey-btree
, HUnit, list-t, lz4, mtl, QuickCheck, random, semigroups, stdenv
, stm, stm-containers, temporary, test-framework
, test-framework-hunit, test-framework-quickcheck2, text
, transformers, unix, vector, xxhash-ffi
}:
mkDerivation {
  pname = "haskey";
  version = "0.3.1.0";
  src = ../.;
  libraryHaskellDepends = [
    base binary bytestring containers directory exceptions filepath
    focus hashable haskey-btree list-t lz4 mtl semigroups stm
    stm-containers transformers unix xxhash-ffi
  ];
  testHaskellDepends = [
    async base binary bytestring containers directory exceptions
    haskey-btree HUnit mtl QuickCheck random temporary test-framework
    test-framework-hunit test-framework-quickcheck2 text transformers
    vector
  ];
  homepage = "https://github.com/haskell-haskey";
  description = "A transactional, ACID compliant, embeddable key-value store";
  license = stdenv.lib.licenses.bsd3;
}
