// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract PokerDrawResolveVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 5357486762750547763894099768622049277094915015919213565139357978777662782304;
    uint256 constant alphay  = 10607267220437769230113375640453244228920782776283083462499005137686963394046;
    uint256 constant betax1  = 16389192845903415571457138014577476370724271859956167562610863588841263859796;
    uint256 constant betax2  = 17432211900774682868679786146042359414485306330191417978252039248886651004425;
    uint256 constant betay1  = 1616887969358894033906341518649972022736041914580546238549954870880344722022;
    uint256 constant betay2  = 7258877284214958503381038950105338251026862874227765945909767641467129035964;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 16185113063181948158692502977586839058602534880630009821886129737113554513528;
    uint256 constant deltax2 = 13543205747164439664896625176756290874447184958482392615684413570356283102454;
    uint256 constant deltay1 = 5187408775059577203375740216491976267696585991159857173554204390959343096136;
    uint256 constant deltay2 = 20611495486087909777880291007473871098213684776042484746964200655780518388861;

    
    uint256 constant IC0x = 20074618021947505957550869420187145590311396755125519450969199872769413106865;
    uint256 constant IC0y = 4246032830753774339674469956288285936189245614576037523023158963065106415844;
    
    uint256 constant IC1x = 6949715867772868740722894430470369885735009874162197731526530614644837673982;
    uint256 constant IC1y = 470964943496670087662240094554661581481552833510079713420896992141908007924;
    
    uint256 constant IC2x = 16158631783389311801945295554974094231693668702689416738970255225217868766997;
    uint256 constant IC2y = 11356496713067408716947860125322076111379925345478117384184550630787086301092;
    
    uint256 constant IC3x = 15503470759457971232823173726881605036654067709989088361117767246633814596523;
    uint256 constant IC3y = 17097648548757985473604368226791937489054093601441264306091855390738814464763;
    
    uint256 constant IC4x = 2321612757218828580696714869482009890074267040056875633573833982004625157035;
    uint256 constant IC4y = 14973966272347899186573821248123694259953034496849909949514642062722381118373;
    
    uint256 constant IC5x = 11586506565645850455067921127081535050952544153943749361367905817814150934853;
    uint256 constant IC5y = 2615376885179937527728848074849608783187232529936678668530934880608805857863;
    
    uint256 constant IC6x = 19730933171211572547270793889388843391150965497710379837248286083783965755614;
    uint256 constant IC6y = 2293480469351127298879866820981778139818227541674043084738256567361875754790;
    
    uint256 constant IC7x = 6946876002036371142524515325050516901778609938111468760268499566807559184255;
    uint256 constant IC7y = 20199054737382564658991470271796062836234660361043352645624996008279978653382;
    
    uint256 constant IC8x = 3606423020537267433066235878400324772608014239682624326952675863207876629798;
    uint256 constant IC8y = 20155197243326837267299871478701878612595993997170511822264617565325116893792;
    
    uint256 constant IC9x = 16887788876305428683239421796435345948611131673525866191760002259650127345701;
    uint256 constant IC9y = 14762476277281966753108381523048884670053787642950643489230252443312958938789;
    
    uint256 constant IC10x = 13987537720154833646056097444744904387147643318512698361386461761067470933247;
    uint256 constant IC10y = 21614485285579344199906722765383725149741244232463919633366275331955668834785;
    
    uint256 constant IC11x = 5764794239561527654669863442610356638746879759503213599184613827553035266456;
    uint256 constant IC11y = 9660899640551193084914935249513314899631916094465182555840579675248953668575;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[11] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
