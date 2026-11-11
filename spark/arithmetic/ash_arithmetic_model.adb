with Ash_Arithmetic_Lemmas;

package body Ash_Arithmetic_Model
   with SPARK_Mode
is
   procedure Check_Division_Identity (Numerator : U64; Denominator : U64) is
   begin
      null;
   end Check_Division_Identity;

   procedure Check_No_Subtract_Transition
      (Prefix : U64; Denominator : U64; Bit_Value : U64)
   is
      Q : constant U64 := Prefix / Denominator
      with Ghost;

      R : constant U64 := Prefix rem Denominator
      with Ghost;

      New_Prefix : constant U64 := 2 * Prefix + Bit_Value
      with Ghost;

      New_Remainder : constant U64 := 2 * R + Bit_Value
      with Ghost;
   begin
      Check_Division_Identity(Prefix, Denominator);

      Check_Euclidean_Identity(Prefix, Denominator);

      Check_Quotient_Uniqueness(New_Prefix, Denominator, 2 * Q, New_Remainder);

      pragma Assert(R < Denominator);

      Ash_Arithmetic_Lemmas.Check_No_Subtract_Branch(R, Denominator, Bit_Value);

   end Check_No_Subtract_Transition;

   procedure Check_Euclidean_Identity (Numerator : U64; Denominator : U64) is
   begin
      null;
   end Check_Euclidean_Identity;

   procedure Check_Quotient_Uniqueness
      (Numerator : U64; Denominator : U64; Quotient : U64; Remainder : U64) is
   begin
      null;
   end Check_Quotient_Uniqueness;

end Ash_Arithmetic_Model;
