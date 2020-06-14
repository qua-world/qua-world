{ mkDerivation, base, GLUT, hspec, hspec-discover, LambdaHack
, OpenGL, optparse-applicative, StateVar, stdenv, text
}:
mkDerivation {
  pname = "partir-qua-world";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [ base ];
  executableHaskellDepends = [
    base GLUT LambdaHack OpenGL optparse-applicative StateVar text
  ];
  testHaskellDepends = [ base hspec LambdaHack text ];
  testToolDepends = [ hspec-discover ];
  doHaddock = false;
  homepage = "https://github.com/qua-world/partir.qua.world";
  description = "GUI Client and Client Interfaces for qua.world";
  license = stdenv.lib.licenses.mit;
}
