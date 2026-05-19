double thermalWidthInPoints(int mm) {
  switch (mm) {
    case 58: return 164.41;
    case 72: return 204.09;
    case 80: return 226.77;
    default: return 226.77;
  }
}

String thermalWidthLabel(int mm) => '${mm}mm';
