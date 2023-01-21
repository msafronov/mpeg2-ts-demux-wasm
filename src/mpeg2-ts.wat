(module
    ;; ++++++++++++++++++++++++++++++++++++++++++++++++++++
    ;; mpeg2-ts.wat
    ;; ++++++++++++++++++++++++++++++++++++++++++++++++++++

    ;; ----------------------------------------------------
    ;; transport packet
    ;; ----------------------------------------------------

    (func $transport_packet (param $offset i32)
        ;; PID
        (i32.or
            (i32.shl
                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x01)))
                    (i32.const 0x1F))
                (i32.const 0x08))

            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x02))))

        global.set $transport_packet_pid

        ;; payload_unit_start_indicator
        (i32.and
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x01)))
            (i32.const 0x40))
        i32.const 0x00
        i32.gt_u

        global.set $transport_packet_payload_unit_start_indicator

        ;; adaptation_field_control
        (i32.and
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x03)))
            (i32.const 0x30))

        global.set $transport_packet_adaptation_field_control
    )


    ;; ----------------------------------------------------
    ;; adaptation field
    ;; ----------------------------------------------------

    (func $adaptation_field (param $offset i32)
        (global.set
            $adaptation_field_length
            (i32.load8_u
                (local.get $offset)))
    )

    (func $adaptation_field_get_skip_offset (result i32)
        global.get $transport_packet_adaptation_field_control
        i32.const 0x10
        i32.gt_u

        (if
            (then
                (return
                    (i32.add
                        (i32.const 0x01)
                        (global.get $adaptation_field_length)))
            )
        )

        i32.const 0x00
    )


    ;; ----------------------------------------------------
    ;; pat (program association table)
    ;; ----------------------------------------------------

    (func $pat (param $offset i32)
        ;; pointer_field
        global.get $transport_packet_payload_unit_start_indicator

        (if
            (then
                (local.set
                    $offset
                    (i32.add
                        (local.get $offset)
                        (i32.const 0x01)))
            )
        )

        ;; table_id
        ;; support "program_association_section" only
        (i32.load8_u
            (local.get $offset))
        i32.const 0x00
        i32.ne

        (if
            (then
                return
            )
        )

        ;; program_number
        ;; support "program_map_PID" only
        (i32.add
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x08)))
            
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x09))))
        i32.const 0x00
        i32.eq

        (if
            (then
                return
            )
        )

        ;; program_map_PID
        (i32.or
            (i32.shl
                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x0A)))
                    (i32.const 0x1F))
                (i32.const 0x08))
            
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x0B))))

        global.set $pat_program_map_pid
    )


    ;; ----------------------------------------------------
    ;; pmt (program map table)
    ;; ----------------------------------------------------

    (func $pmt (param $offset i32)
        (local $pmt_section_length i32)
        (local $stream_type i32)
        (local $elementary_pid i32)

        ;; pointer_field
        global.get $transport_packet_payload_unit_start_indicator

        (if
            (then
                (local.set
                    $offset
                    (i32.add
                        (local.get $offset)
                        (i32.const 0x01)))
            )
        )

        ;; section_length
        (i32.add
            ;; 3 first bytes of the section - 4 bytes of CRC_32 from the end of the section
            (i32.sub
                (i32.or
                    (i32.shl
                        (i32.and
                            (i32.load8_u
                                (i32.add
                                    (local.get $offset)
                                    (i32.const 0x01)))
                            (i32.const 0x03))
                        (i32.const 0x08))

                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x02))))

                (i32.const 0x01))

            (local.get $offset))

        local.set $pmt_section_length

        ;; program_info_length
        (i32.or
            (i32.shl
                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x0A)))
                    (i32.const 0x03))
                (i32.const 0x08))

            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x0B))))

        ;; increase local offset ("program_info_length" value + 12 bytes of the section)
        (i32.add
            (local.get $offset)
            (i32.const 0x0C))
        i32.add

        local.set $offset

        ;; "stream_type" .. "ES_info_length"
        (loop $pmt_loop
            ;; stream_type
            (i32.load8_u
                (local.get $offset))

            local.set $stream_type

            ;; elementary_PID
            (i32.or
                (i32.shl
                    (i32.and
                        (i32.load8_u
                            (i32.add
                                (local.get $offset)
                                (i32.const 0x01)))
                        (i32.const 0x1F))
                    (i32.const 0x08))

                (i32.load8_u
                    (i32.add
                        (local.get $offset)
                        (i32.const 0x02))))

            local.set $elementary_pid

            ;; program mappings

            ;; ISO/IEC 13818-7 Audio with ADTS transport syntax
            (i32.eq
                (local.get $stream_type)
                (i32.const 0x0F))

            (if
                (then
                    (global.set
                        $pmt_elementary_pid_audio
                        (local.get $elementary_pid))
                )
            )

            ;; AVC video stream as defined in ITU-T Rec. H.264 | ISO/IEC 14496-10 Video
            (i32.eq
                (local.get $stream_type)
                (i32.const 0x1B))

            (if
                (then
                    (global.set
                        $pmt_elementary_pid_video
                        (local.get $elementary_pid))
                )
            )

            ;; loop continuation
            ;; skip first 5 bytes of a description + "ES_info_length" size
            (i32.add
                (i32.or
                    (i32.shl
                        (i32.and
                            (i32.load8_u
                                (i32.add
                                    (local.get $offset)
                                    (i32.const 0x03)))
                            (i32.const 0x0F))
                        (i32.const 0x08))

                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x04))))

                (i32.add
                    (local.get $offset)
                    (i32.const 0x05)))

            local.tee $offset
            local.get $pmt_section_length
            i32.lt_u

            (if
                (then
                    br $pmt_loop
                )
            )
        )
    )


    ;; ----------------------------------------------------
    ;; pes
    ;; ----------------------------------------------------

    (func $pes (param $offset i32)
        (local $pes_data_length i32)
        (local $pts_dts_offset i32)

        ;; prefix checking
        (global.get $transport_packet_payload_unit_start_indicator)

        (if
            (then
                ;; packet_start_code_prefix
                (i32.or
                    (i32.or
                        (i32.shl
                            (i32.load8_u
                                (local.get $offset))
                            (i32.const 0x10))
                        
                        (i32.shl
                            (i32.load8_u
                                (i32.add
                                    (local.get $offset)
                                    (i32.const 0x01)))
                            (i32.const 0x08)))

                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x02)))
                )
                i32.const 0x01
                i32.ne

                (if
                    (then
                        (return)   
                    )
                )

                ;; PTS_DTS_flags
                (global.set
                    $pes_pts_dts_flags
                    (i32.and
                        (i32.load8_u
                            (i32.add
                                (local.get $offset)
                                (i32.const 0x07)))
                        (i32.const 0xC0)))

                (global.get $pes_pts_dts_flags)
                (i32.const 0x00)
                (i32.ne)

                (if
                    (then
                        ;; offset
                        (local.set
                            $pts_dts_offset
                            (i32.add
                                (local.get $offset)
                                (i32.const 0x09)))
                        
                        ;; pts
                        (i32.eq
                            (global.get $pes_pts_dts_flags)
                            (i32.const 0x80))
                        
                        (if
                            (then
                                (call $pes_parse_pts
                                    (local.get $pts_dts_offset))
                            )
                        )

                        ;; pts + dts
                        (i32.eq
                            (global.get $pes_pts_dts_flags)
                            (i32.const 0xC0))

                        (if
                            (then
                                ;; pts
                                (call $pes_parse_pts
                                    (local.get $pts_dts_offset))
                                ;; dts
                                (call $pes_parse_dts
                                    (local.get $pts_dts_offset))
                            )
                        )
                    )
                )

                ;; record metadata

                (global.set
                    $memory_metadata_current_offset
                    (i32.add
                        (global.get $memory_metadata_offset)
                        (global.get $memory_metadata_length)))

                (global.set
                    $memory_metadata_length
                    (i32.add
                        (global.get $memory_metadata_length)
                        (global.get $memory_metadata_packet_length)))

                ;; pid
                (i32.store
                    (global.get $memory_metadata_current_offset)
                    (global.get $transport_packet_pid))

                ;; pts and dts timestamps
                (i32.store
                    (i32.add
                        (global.get $memory_metadata_current_offset)
                        (i32.const 0x0A))
                    (global.get $pes_pts))

                (i32.store
                    (i32.add
                        (global.get $memory_metadata_current_offset)
                        (i32.const 0x0E))
                    (global.get $pes_dts))
            )
        )

        ;; calculate pes data length
        (i32.sub
            (i32.add
                (global.get $memory_cursor)
                (global.get $transport_packet_size))
            (local.get $offset))

        (local.set $pes_data_length)

        ;; PES_header_data_length
        ;; first 9 bytes of the section + "PES_header_data_length" value
        (i32.add
            (i32.const 0x09)
            (i32.load8_u
                (i32.add
                    (local.get $offset)
                    (i32.const 0x08))))

        (local.set $offset)

        ;; record elementary stream
        (memory.copy
            (i32.add
                (global.get $memory_es_offset)
                (global.get $memory_es_length))
            (local.get $offset)
            (local.get $pes_data_length))
        

        ;; record metadata

        ;; offset in the linear memory (from es_offset to es_len)
        (global.get $transport_packet_payload_unit_start_indicator)

        (if
            (then
                (i32.store
                    (i32.add
                        (global.get $memory_metadata_current_offset)
                        (i32.const 0x02))
                    (i32.add
                        (global.get $memory_es_offset)
                        (global.get $memory_es_length)))
            )
        )

        ;; length
        (i32.store
            (i32.add
                (global.get $memory_metadata_current_offset)
                (i32.const 0x06))
            (i32.add
                (i32.load
                    (i32.add
                        (global.get $memory_metadata_current_offset)
                        (i32.const 0x06)))
                (local.get $pes_data_length)))

        ;; increase es length
        (global.set
            $memory_es_length
            (i32.add
                (global.get $memory_es_length)
                (local.get $pes_data_length)))
    )

    (func $pes_parse_pts (param $offset i32)
        (call $pes_parse_pts_dts
            (local.get $offset))
        
        global.set $pes_pts
    )

    (func $pes_parse_dts (param $offset i32)
        (call $pes_parse_pts_dts
            (i32.add
                (local.get $offset)
                (i32.const 0x05)))

        global.set $pes_dts
    )

    (func $pes_parse_pts_dts (param $offset i32) (result i32)
        ;; algorithm:
        ;; (1) | (2) | (3)

        ;; (1)
        ;; PTS [32..30] / DTS [32..30]
        ;;
        ;; (offset[0] & 0x0E) << 30)
        (i32.shl
            (i32.and
                (i32.load8_u
                    (local.get $offset))
                (i32.const 0x0E))
            (i32.const 0x1E))

        ;; (2)
        ;; PTS [29..15] / DTS [29..15]
        ;;
        ;; (((offset[1] << 8) | (offset[2] & 0xFE)) << 14)
        (i32.shl
            (i32.or
                (i32.shl
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x01)))
                    (i32.const 0x08))

                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x02)))
                    (i32.const 0xFE)))
            (i32.const 0x0E))
        
        i32.or

        ;; (3)
        ;; PTS [14..0] / DTS [14..0]
        ;;
        ;; (((offset[3] << 8) | (offset[4] & 0xFE)) >> 1
        (i32.shr_u
            (i32.or
                (i32.shl
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x03)))
                    (i32.const 0x08))

                (i32.and
                    (i32.load8_u
                        (i32.add
                            (local.get $offset)
                            (i32.const 0x04)))
                    (i32.const 0xFE)))
            (i32.const 0x01))

        i32.or
    )
)