with Interfaces;
use type Interfaces.Unsigned_64;

package Ash_Arithmetic_Lemmas
   with SPARK_Mode
is
   subtype U64 is Interfaces.Unsigned_64;

   procedure Check_Gap (Remainder : U64; Denominator : U64)
   with
      Ghost,
      Pre  => Remainder < Denominator,
      Post => Denominator - Remainder > 0;

   procedure Check_Subtract_Branch
      (Remainder : U64; Denominator : U64; Bit_Value : U64)
   with
      Ghost,
      Pre  =>
         Denominator > 0
         and then Remainder < Denominator
         and then Bit_Value <= 1
         and then Remainder >= Denominator - Remainder,
      Post => (Remainder - (Denominator - Remainder)) + Bit_Value < Denominator;

   procedure Check_No_Subtract_Branch
      (Remainder : U64; Denominator : U64; Bit_Value : U64)
   with
      Ghost,
      Pre  =>
      Denominator > 0
         and then Remainder < Denominator
         and then Bit_Value <= 1
         and then Remainder < Denominator - Remainder
         and then
         (Bit_Value = 0 or else Remainder /= Denominator - Remainder - 1),
      Post => (Interfaces.Shift_Left (Remainder, 1) or Bit_Value) < Denominator;

end Ash_Arithmetic_Lemmas;
