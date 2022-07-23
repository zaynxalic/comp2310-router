--
--  Framework: Uwe R. Zimmer, Australia, 2019
--
with Exceptions; use Exceptions;
with Queue_Pack_Protected_Generic;

package body Generic_Router is

   task body Router_Task is

      Connected_Routers : Ids_To_Links;

      type Byte is mod 512;

      package Mail_Q is new Queue_Pack_Protected_Generic (Element => Messages_Mailbox,
                                                          Index => Byte);
      use Mail_Q;

      type MailBox_Q is new Mail_Q.Protected_Queue;

   begin
      accept Configure (Links : Ids_To_Links) do
         Connected_Routers := Links;
      end Configure;

      declare
         Port_List : constant Connected_Router_Ports := To_Router_Ports (Task_Id, Connected_Routers);

         Local_Received : Inter_Received_Messages;
         -- routing table is stored locally

         Default_Hop : constant Positive := 1;

         Index : constant Natural := Natural (Task_Id);

         Message_Sent : Inter_Sent_Messages;

         MailBox_Queue : MailBox_Q;

         task Establish_Commmunication;
         task body Establish_Commmunication is

            Start_Router : Router_Range;

            End_Router : constant Router_Range := Task_Id;

            Counter : Natural := 0;

         begin

            While_Loop :
            while Counter <= 2 * Integer (Router_Range'Last) loop

               for ix in Port_List'Range loop

                  Start_Router := Port_List (ix).Id;

                  Message_Sent.Start_End_Node := (Start_Router, End_Router);

                  Message_Sent.Hop_Counter := Default_Hop;

                  Message_Sent.Array_Path_Hop := Local_Received.Array_Path_Hop;

                  Port_List (ix).Link.all.Setup_Routing_Table (Message_Sent);

               end loop;

               Counter := Counter + 1;

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

                  -- input the value which can be directly input in.
                  Local_Received.Array_Path_Hop (Index).Hop_Counter := 0;
                  Local_Received.Array_Path_Hop (Index).Start_End_Vector := Natural_Vectors.Empty_Vector;

                  for ix in Local_Received.Array_Path_Hop'Range loop

                     declare
                        Start_End_Vector : Natural_Vectors.Vector;
                     begin

                        Start_End_Vector.Append (Integer (Message.Start_End_Node (1)));
                        Start_End_Vector.Append (Integer (Message.Start_End_Node (2)));

                        if Start_End_Vector.Last_Element = ix then

                           Local_Received.Array_Path_Hop (ix). Start_End_Vector := Start_End_Vector;
                           Local_Received.Array_Path_Hop (ix). Hop_Counter      := Default_Hop;

                        end if;
                     end;

                  end loop;

                  for index_x in Local_Received.Array_Path_Hop'Range loop

                     declare

                        Last_Node_Id : Positive;
                        Path_V : Natural_Vectors.Vector;

                     begin

                        if not Array_Index_Vector_Is_Empty (Local_Received.Array_Path_Hop, index_x) then
                           -- check whether index of ix in null or not
                           Last_Node_Id := Local_Received.Array_Path_Hop (index_x).Start_End_Vector.Last_Element;
                           -- analyse the message last node

                           for index_y in Message.Array_Path_Hop'Range loop

                              -- iterate the message table

                              if not Message.Array_Path_Hop (index_y).Start_End_Vector.Is_Empty then
                                 if Message.Array_Path_Hop (index_y).Start_End_Vector.First_Element = Last_Node_Id then

                                    -- if the start node of message is the end of the local router table
                                    Natural_Vectors.Append (Path_V, Local_Received.Array_Path_Hop (index_x).Start_End_Vector);
                                    Path_V.Delete_Last;
                                    Natural_Vectors.Append (Path_V, Message.Array_Path_Hop (index_y).Start_End_Vector);

                                    if Local_Received.Array_Path_Hop (index_y).Hop_Counter > Integer (Natural_Vectors.Length (Path_V)) then

                                       Local_Received.Array_Path_Hop (index_y).Start_End_Vector := Path_V;
                                       Local_Received.Array_Path_Hop (index_y).Hop_Counter := Integer (Natural_Vectors.Length (Path_V));

                                    end if;

                                    Path_V.Clear;
                                    -- reset the temparory vector variable.
                                 end if;
                              end if;

                           end loop;

                        end if;
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

                     Message_To_Transfer.Sender := Task_Id;
                     Message_To_Transfer.Destination := Message.Destination;
                     Message_To_Transfer.Hop_Counter := Default_Hop;
                     Message_To_Transfer.The_Message := Message.The_Message;
                     Next_Hop := Router_Range (Natural_Vectors.Element (Cursor));

                     for ix in Port_List'Range loop
                        if Port_List (ix).Id = Next_Hop then
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

                           Next_Hop := Router_Range (Natural_Vectors.Element (Cursor));

                           Message.Hop_Counter := Message.Hop_Counter + Default_Hop;

                           for ix in Port_List'Range loop
                              if Port_List (ix) .Id = Next_Hop then
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

               accept Shutdown;
               exit;

            end select;
         end loop;
      end;

   exception
      when Exception_Id : others => Show_Exception (Exception_Id);
   end Router_Task;

end Generic_Router;
