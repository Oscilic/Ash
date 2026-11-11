with Interfaces;
use type Interfaces.Unsigned_64;

package Ash_Arithmetic_Model
   with SPARK_Mode
is
   subtype U64 is Interfaces.Unsigned_64;

   procedure Check_Division_Identity (Numerator : U64; Denominator : U64)
   with
      Ghost,
      Pre  => Denominator /= 0,
      Post =>
         Numerator / Denominator <= Numerator
         and then Numerator rem Denominator < Denominator;


   procedure Check_No_Subtract_Transition
      (Prefix : U64; Denominator : U64; Bit_Value : U64)
   with
      Ghost,
      Pre  =>
         Denominator > 0
         and then Bit_Value <= 1
         and then Prefix <= (U64'Last - Bit_Value) / 2
         and then
            (Prefix rem Denominator) < Denominator - (Prefix rem Denominator)
         and then
            (Bit_Value = 0
         or else
            (Prefix rem Denominator) /= Denominator - (Prefix rem Denominator) - 1),
      Post =>
       (2 * Prefix + Bit_Value) / Denominator = 2 * (Prefix / Denominator);

   procedure Check_Euclidean_Identity (Numerator : U64; Denominator : U64)
   with
      Ghost,
      Pre  => Denominator > 0,
      Post =>
         Numerator
       = (Numerator / Denominator) * Denominator + (Numerator rem Denominator);

   procedure Check_Quotient_Uniqueness
      (Numerator : U64; Denominator : U64; Quotient : U64; Remainder : U64)
   with
      Ghost,
      Pre  =>
         Denominator > 0
         and then Remainder < Denominator
         and then Quotient <= Numerator / Denominator
       and then Numerator = Quotient * Denominator + Remainder,
      Post =>
         Quotient = Numerator / Denominator
         and then Remainder = Numerator rem Denominator;

end Ash_Arithmetic_Model;
