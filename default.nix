{ mkDerivation, base, hspec, hspec-discover, stdenv }:
mkDerivation {
  pname = "partir-qua-world";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [ base ];
  executableHaskellDepends = [ base ];
  testHaskellDepends = [ base hspec ];
  testToolDepends = [ hspec-discover ];
  homepage = "https://github.com/qua-world/partir.qua.world";
  description = "GUI Client and Client Interfaces for qua.world";
  license = stdenv.lib.licenses.mit;
}
