--
--  Framework: Uwe R. Zimmer, Australia, 2019
--

-- small amount size of router with under 2 routers drop out could successfully be built.
-- how to deal with exceptions is inspired by XuSi (u6714758)

with Exceptions; use Exceptions;
with Ada.Containers; use Ada.Containers;
package body Generic_Router is

   task body Router_Task is
      Connected_Routers : Ids_To_Links;

   begin
      accept Configure (Links : Ids_To_Links) do
         Connected_Routers := Links;
      end Configure;

      declare
         Port_List : constant Connected_Router_Ports := To_Router_Ports (Task_Id, Connected_Routers);

         Local_Received : Inter_Received_Messages;
         -- message is stored locally and can be updated

         Default_Hop : constant Positive := 1;

         Index : constant Natural := Natural (Task_Id);

         Message_Sent : Inter_Sent_Messages;

         MailBox_Queue : MailBox_Q;

         Vector_Path_Complete : Arr_Router_Available (1 .. Integer (Router_Range'Last)) := (others => True);
         -- if the path is not exist then set the flag to true.
         Flag : Boolean := True;

         task Establish_Commmunication;
         task body Establish_Commmunication is

            Start_Router : Router_Range;

            End_Router : constant Router_Range := Task_Id;

         begin

            While_Loop :
            while Flag loop

               for ix in Port_List'Range loop

                  Start_Router := Port_List (ix).Id;

                  Message_Sent.Start_End_Node := (Start_Router, End_Router);

                  Message_Sent.Hop_Counter := Default_Hop;

                  Message_Sent.Array_Path_Hop := Local_Received.Array_Path_Hop;

                  Message_Sent.Array_Router_Available := Local_Received.Array_Router_Available;

                  if Local_Received.Array_Router_Available (Integer (Port_List (ix).Id)) then
                     Port_List (ix).Link.all.Setup_Routing_Table (Message_Sent);
                  end if;
               end loop;
               delay 0.001;
            end loop While_Loop;
         end Establish_Commmunication;

         function Array_Index_Vector_Is_Empty (Arr : Arr_Path_Hop; Ix : Positive) return Boolean is
         begin
            return Arr (Ix).Start_End_Vector.Is_Empty;
         end Array_Index_Vector_Is_Empty;

      begin
         loop
            select
               accept Setup_Routing_Table (Message : in Inter_Sent_Messages) do
                  Local_Received.Array_Path_Hop (Index).Hop_Counter := 0;
                  Local_Received.Array_Path_Hop (Index).Start_End_Vector := Natural_Vectors.Empty_Vector;

                  for i in Local_Received.Array_Router_Available'Range loop
                     Local_Received.Array_Router_Available (i) :=  Local_Received.Array_Router_Available (i) and then Message.Array_Router_Available (i);
                  end loop;

                  -- update the available router array
                  for ix in Local_Received.Array_Router_Available'Range loop

                     if Vector_Path_Complete (ix) then

                        if not Local_Received.Array_Router_Available (ix) then

                           for v_index in Local_Received.Array_Path_Hop'Range loop
                              if Local_Received.Array_Path_Hop (v_index).Start_End_Vector.Contains (ix) then

                                 Local_Received.Array_Path_Hop (v_index).Start_End_Vector.Clear;
                                 Local_Received.Array_Path_Hop (v_index).Hop_Counter := 0;

                              end if;
                           end loop;
                           Vector_Path_Complete (ix) := False;
                        end if;

                     end if;

                  end loop;
                  -- if router which need to pass through is not available then clear the path

                  for ix in Local_Received.Array_Path_Hop'Range loop

                     declare
                        Start_End_Vector : Natural_Vectors.Vector;
                     begin

                        Start_End_Vector.Append (Integer (Message.Start_End_Node (1)));
                        Start_End_Vector.Append (Integer (Message.Start_End_Node (2)));

                        if Start_End_Vector.Last_Element = ix and then Local_Received.Array_Router_Available (ix) then

                           Local_Received.Array_Path_Hop (ix). Start_End_Vector := Start_End_Vector;
                           Local_Received.Array_Path_Hop (ix). Hop_Counter      := Default_Hop;

                        end if;
                     end;
                  end loop;
                  -- input the value which can be directly input in.

                  for fil_Ele in Local_Received.Array_Path_Hop'Range loop
                     declare
                        Path_V : Natural_Vectors.Vector;
                        Temp_V : Natural_Vectors.Vector;
                        Cursor_A : Natural_Vectors.Cursor;
                        ele : Positive;
                     begin

                        for vec in Message.Array_Path_Hop'Range loop
                           if (not Message.Array_Path_Hop (vec).Start_End_Vector.Is_Empty) and then Natural_Vectors.Contains (Message.Array_Path_Hop (vec).Start_End_Vector,fil_Ele)
                             and then fil_Ele /= Integer (Task_Id) and then Local_Received.Array_Router_Available (fil_Ele) then
                              if fil_Ele = Integer (Message.Array_Path_Hop (vec).Start_End_Vector.Last_Element) then
                                 Cursor_A := Message.Array_Path_Hop (vec).Start_End_Vector.Last;
                                 Natural_Vectors.Previous (Cursor_A);
                                 ele := Positive (Natural_Vectors.Element (Cursor_A));
                                 if not Array_Index_Vector_Is_Empty (Local_Received.Array_Path_Hop, ele) then
                                    Temp_V := Local_Received.Array_Path_Hop (ele).Start_End_Vector;
                                    Temp_V.Delete_Last;
                                    Natural_Vectors.Append (Temp_V, Message.Array_Path_Hop (vec).Start_End_Vector);

                                    if ((Array_Index_Vector_Is_Empty (Local_Received.Array_Path_Hop, fil_Ele) and then Local_Received.Array_Router_Available (fil_Ele)))
                                      or else Natural_Vectors.Length (Local_Received.Array_Path_Hop (fil_Ele).Start_End_Vector) > Natural_Vectors.Length (Temp_V) then

                                       Local_Received.Array_Path_Hop (fil_Ele).Start_End_Vector := Temp_V;
                                       Local_Received.Array_Path_Hop (fil_Ele).Hop_Counter := Integer (Natural_Vectors.Length (Temp_V));

                                    end if;
                                 end if;

                              elsif fil_Ele = Integer (Message.Array_Path_Hop (vec).Start_End_Vector.First_Element) then
                                 Cursor_A := Message.Array_Path_Hop (vec).Start_End_Vector.First;
                                 Natural_Vectors.Next (Cursor_A);
                                 ele := Positive (Natural_Vectors.Element (Cursor_A));
                                 if not Array_Index_Vector_Is_Empty (Local_Received.Array_Path_Hop, ele) then
                                    Temp_V := Local_Received.Array_Path_Hop (ele).Start_End_Vector;
                                    Temp_V.Delete_Last;
                                    Path_V := Message.Array_Path_Hop (vec).Start_End_Vector;
                                    Natural_Vectors.Reverse_Elements (Path_V);
                                    Natural_Vectors.Append (Temp_V, Path_V);

                                    if ((Array_Index_Vector_Is_Empty (Local_Received.Array_Path_Hop, fil_Ele) and then Local_Received.Array_Router_Available (fil_Ele)))
                                      or else Natural_Vectors.Length (Local_Received.Array_Path_Hop (fil_Ele).Start_End_Vector) > Natural_Vectors.Length (Temp_V) then
                                       Local_Received.Array_Path_Hop (fil_Ele).Start_End_Vector := Temp_V;
                                       Local_Received.Array_Path_Hop (fil_Ele).Hop_Counter := Integer (Natural_Vectors.Length (Temp_V));
                                    end if;
                                 end if;
                              Natural_Vectors.Clear (Temp_V);
                              Natural_Vectors.Clear (Path_V);
                              -- reset the vector
                              end if;
                           end if;

                        end loop;

                     end;

                  end loop;
               end Setup_Routing_Table;

            or
               accept Send_Message (Message : Messages_Client) do
                  declare
                     Message_To_Transfer : Message_To_Neightbour;
                     Cursor : constant Natural_Vectors.Cursor := Local_Received.Array_Path_Hop (Integer (Message.Destination)).
                       Start_End_Vector.To_Cursor (Index => 2);
                     Next_Hop : Router_Range;
                     -- the latter element cursor
                  begin
                     Flag := False;
                     Message_To_Transfer.Sender := Task_Id;
                     Message_To_Transfer.Destination := Message.Destination;
                     Message_To_Transfer.Hop_Counter := Default_Hop;
                     Message_To_Transfer.The_Message := Message.The_Message;
                     Next_Hop := Router_Range (Natural_Vectors.Element (Cursor));

                     for ix in Port_List'Range loop
                        if Port_List (ix).Id = Next_Hop and then Local_Received.Array_Router_Available (Integer (Port_List (ix).Id)) then
                           Port_List (ix).Link.all.Transform (Message_To_Transfer);
                        end if;
                        -- send the message to the next router
                     end loop;
                  end;
               end Send_Message;
            or

               accept Transform (Message : out Message_To_Neightbour) do

                  declare

                     Next_Hop : Router_Range;
                     Mes_To_Neighbour :  Messages_Mailbox;

                  begin
                     if Task_Id = Message.Destination then

                        Mes_To_Neighbour.Hop_Counter := Message.Hop_Counter;
                        Mes_To_Neighbour.The_Message := Message.The_Message;
                        Mes_To_Neighbour.Sender := Message.Sender;
                        MailBox_Queue.Enqueue (Mes_To_Neighbour);

                        -- store the message into queue.
                     else
                        declare

                           Cursor : constant Natural_Vectors.Cursor := Local_Received.Array_Path_Hop (Integer (Message.Destination)).
                             Start_End_Vector.To_Cursor (Index => 2);

                        begin
                           -- Put_Line (Count_Type'Image (Natural_Vectors.Length((Local_Received.Array_Path_Hop (Integer (Message.Destination)).Start_End_Vector))));
                           Next_Hop := Router_Range (Natural_Vectors.Element (Cursor));
                           Message.Hop_Counter := Message.Hop_Counter + Default_Hop;

                           for ix in Port_List'Range loop
                              if Port_List (ix).Id = Next_Hop and then Local_Received.Array_Router_Available (Integer (Port_List (ix).Id)) then
                                 Port_List (ix) .Link.all.Transform (Message);
                              end if;
                           end loop;
                        end;

                     end if;
                  end;
               end Transform;
            or

               accept Receive_Message (Message : out Messages_Mailbox) do

                  declare
                     Sender : Router_Range;
                     pragma Unreferenced (Sender);

                     The_Message : The_Core_Message;
                     pragma Unreferenced (The_Message);

                     Hop_Counter : Natural;
                     pragma Unreferenced (Hop_Counter);

                  begin
                     if not MailBox_Queue.Is_Empty then

                        MailBox_Queue.Dequeue (Message);
                        -- dequeue the message
                        Sender := Message.Sender;

                        The_Message := Message.The_Message;

                        Hop_Counter := Message.Hop_Counter;
                     else
                        null;
                     end if;
                  end;

               end Receive_Message;
            or

               accept Shutdown do

                  Local_Received.Array_Router_Available (Integer (Task_Id)) := False;
                  -- set the available situation to false
                  Flag := False;
                  for ix in Local_Received.Array_Path_Hop'Range loop
                     Local_Received.Array_Path_Hop (ix) .Start_End_Vector := Natural_Vectors.Empty_Vector;
                     Local_Received.Array_Path_Hop (ix) .Hop_Counter := 0;
                  end loop;
                  -- Delete invalid routing
                  -- Put_Line (Router_Range'Image (Task_Id) & " ShutDown");

                  for ix in Port_List'Range loop
                     if Local_Received.Array_Router_Available (Integer (Port_List (ix).Id)) then
                        Message_Sent.Start_End_Node := (others => Router_Range'Invalid_Value);
                        Message_Sent.Hop_Counter := 0;
                        Message_Sent.Array_Path_Hop := Local_Received.Array_Path_Hop;
                        Message_Sent.Array_Router_Available := Local_Received.Array_Router_Available;
                        Port_List (ix).Link.all.Setup_Routing_Table (Message_Sent);
                     end if;
                  end loop;

               end Shutdown;
               exit;

            end select;
         end loop;
      end;

   exception
      when Exception_Id : others => Show_Exception (Exception_Id);
   end Router_Task;

end Generic_Router;
