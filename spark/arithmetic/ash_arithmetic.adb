with Interfaces;
use type Interfaces.Unsigned_64;

package body Ash_Arithmetic
  with SPARK_Mode
is
   function Divide_Unsigned
     (Numerator   : U64;
      Denominator : U64) return Division_Result
   is
      Quotient  : U64 := 0;
      Remainder : U64 := 0;
      Bit_Value : U64;
      Carry     : Boolean;
   begin
      for I in reverse 0 .. 63 loop
         Bit_Value :=
           Interfaces.Shift_Right (Numerator, I) and 1;

         Carry :=
           Interfaces.Shift_Right (Remainder, 63) /= 0;

         Remainder :=
           Interfaces.Shift_Left (Remainder, 1) or Bit_Value;

         if Carry or else Remainder >= Denominator then
            Remainder := Remainder - Denominator;

            Quotient :=
              Quotient or Interfaces.Shift_Left (U64 (1), I);
         end if;
         pragma Loop_Invariant (Remainder < Denominator);
      end loop;
      return
        (Quotient  => Quotient,
         Remainder => Remainder);
   end Divide_Unsigned;

end Ash_Arithmetic;