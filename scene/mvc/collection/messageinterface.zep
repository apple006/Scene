
/**
 * Message Interface
*/

namespace Scene\Mvc\Collection;

/**
 * Scene\Mvc\Collection\Message
 *
 * Interface for Scene\Mvc\Collection\Message
 */
interface MessageInterface
{

    /**
     * Scene\Mvc\Collection\Message constructor
     *
     * @param string message
     * @param string field
     * @param string type
     */
    public function __construct(message, field = null, type = null);

    /**
     * Sets message type
     *
     * @param string type
     */
    public function setType(type);

    /**
     * Returns message type
     *
     * @return string
     */
    public function getType();

    /**
     * Sets verbose message
     *
     * @param string message
     */
    public function setMessage(message);

    /**
     * Returns verbose message
     *
     * @return string
     */
    public function getMessage();

    /**
     * Sets field name related to message
     *
     * @param string field
     */
    public function setField(field);

    /**
     * Returns field name related to message
     *
     * @return string
     */
    public function getField();

    /**
     * Magic __toString method returns verbose message
     */
    public function __toString() -> string;

    /**
     * Magic __set_state helps to recover messsages from serialization
     *
     * @param array $message
     * @return \Scene\Mvc\Collection\MessageInterface
     */
    public static function __set_state(array! message) -> <MessageInterface>;

}
