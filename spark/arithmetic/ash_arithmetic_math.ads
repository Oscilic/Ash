with SPARK.Big_Integers;

package Ash_Arithmetic_Math
  with SPARK_Mode
is
   use SPARK.Big_Integers;

   procedure Check_Quotient_Uniqueness
     (Numerator   : Big_Integer;
      Denominator : Big_Integer;
      Quotient    : Big_Integer;
      Remainder   : Big_Integer)
   with
     Ghost,
     Pre  =>
       Denominator > To_Big_Integer (0)
       and then Remainder >= To_Big_Integer (0)
       and then Remainder < Denominator
       and then Numerator = Quotient * Denominator + Remainder,
     Post =>
       Quotient = Numerator / Denominator
       and then Remainder = Numerator rem Denominator;

end Ash_Arithmetic_Math;
