## Layering

* Layering means decomposing the problem into more manageable components(Layers).
* provides more modular design
* easy to troubleshoot
* ## Basic Networking
* OSI model

  * The OSI model is a conceptual framework for describing how two systems communicate over a network.
  * The OSI model breaks the responsibilities of the network into seven distinct layers, each with different functions to aid in transmitting information from one system to another.
  * Each layer takes data from the previous layer and encapsulates it to make its Protocol Data Unit (PDU). PDU describes the data of each layer
  * Application Layer:

    * Top layer of OSI model
    * The layer where actual applications live
    * The layer what we use daily
  * Presentation layer:
  * The presentation layer transforms data into the form that the application accepts.
  * This layer formats and encrypts data to be sent across a network.
  * Session Layer:
  * Its responsible for sending and receiving data same time
  * It also establishes procedures for performing checkpointing, suspending, restarting, and terminating a session.
* Transport Layer:

  * transfers data between applications, providing reliable data transfer services to the upper layers
  * TCP/IP has two protocols at this layer:
    * TCP and User
    * Datagram Protocol (UDP).
* Network Layer:

  * Translate variable length data from host on one network to host on another network
* Data Link Layer:

  * responsible for the host-to-host transfers on the same network
* Physical Layer:

  * This layer converts data in the form of digital bits into electrical, radio, or optical signals.
  * Think of this layer as the physical devices, like cables, switches, and wireless access points

## TCP/IP
